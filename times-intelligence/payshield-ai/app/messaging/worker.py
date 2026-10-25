"""Service Bus consumer:  python -m app.messaging.worker

Queue payshield-analysis-requested, body {tenantUid, companyUid, payRunUid, fingerprint, trigger, requestedBy}.
The tenant comes from a trusted internal channel (managed identity on the namespace), and is still checked
against the tenant store and the company's subscription before anything runs. Bad bodies are dead-lettered;
transient failures are abandoned and retried; the last attempt is dead-lettered with the failure recorded."""

from __future__ import annotations

import json
import logging
import signal
import uuid

from app.core.config import get_settings
from app.core.errors import Conflict, PayShieldError
from app.core.logging import configure_logging, set_correlation_id
from app.core.security import VerifiedService
from app.main import Runtime
from app.security.permissions import build_service_context

log = logging.getLogger(__name__)
REQUIRED = ("tenantUid", "companyUid", "payRunUid")


def parse(body: bytes | str) -> dict | None:
    try:
        msg = json.loads(body)
        for k in REQUIRED:
            uuid.UUID(str(msg[k]))
        return msg
    except (ValueError, KeyError, TypeError):
        return None


def handle(rt: Runtime, msg: dict) -> None:
    who = VerifiedService("servicebus")
    ctx = build_service_context(rt.tenants, rt.payroll, who, msg["tenantUid"], msg["companyUid"], msg.get("fingerprint", ""))
    trigger = msg.get("trigger") if msg.get("trigger") in ("EVENT", "SWEEPER") else "EVENT"
    rt.service(ctx).analyze_pay_run(ctx, msg["payRunUid"], trigger)


def run() -> None:
    from azure.servicebus import ServiceBusClient

    settings = get_settings()
    configure_logging(settings)
    rt = Runtime(settings)
    m = settings.messaging
    conn = m.servicebus_connection_string.get_secret_value()
    if conn:
        client = ServiceBusClient.from_connection_string(conn)
    else:
        from azure.identity import DefaultAzureCredential

        client = ServiceBusClient(m.servicebus_fully_qualified_namespace, DefaultAzureCredential())
    stop = {"flag": False}
    signal.signal(signal.SIGTERM, lambda *_: stop.update(flag=True))
    with client, client.get_queue_receiver(m.analysis_queue, max_wait_time=20) as receiver:
        log.info("worker started", extra={"event": "worker_started"})
        while not stop["flag"]:
            for message in receiver.receive_messages(max_message_count=5, max_wait_time=20):
                set_correlation_id(str(message.message_id or uuid.uuid4()))
                msg = parse(b"".join(message.body))
                if msg is None:
                    receiver.dead_letter_message(message, reason="INVALID_BODY")
                    continue
                try:
                    handle(rt, msg)
                    receiver.complete_message(message)
                except Conflict as e:  # e.g. run still processing / disabled: nothing to retry forever
                    log.info("analysis skipped", extra={"error_code": e.code})
                    receiver.complete_message(message)
                except PayShieldError as e:
                    receiver.dead_letter_message(message, reason=e.code)
                except Exception:  # noqa: BLE001 - transient: retry until max delivery count
                    log.exception("analysis message failed", extra={"error_code": "ANALYSIS_FAILED"})
                    if message.delivery_count >= m.max_delivery_attempts:
                        receiver.dead_letter_message(message, reason="MAX_ATTEMPTS")
                    else:
                        receiver.abandon_message(message)


if __name__ == "__main__":
    run()
