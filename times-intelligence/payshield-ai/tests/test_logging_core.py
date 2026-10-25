"""Tests for app.core.logging: json shape, extra allow-list, correlation ids, exception rendering."""

from __future__ import annotations

import asyncio
import io
import json
import logging
import subprocess
import sys
import uuid
from collections.abc import Iterator
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Any

import pytest
from pydantic import SecretStr

from app.core import logging as plog
from app.core.config import Settings

PACKAGE_ROOT = Path(__file__).resolve().parents[1]


@dataclass
class _FakeSettings:
    service_name: str = "payshield-ai"
    environment: str = "dev"
    log_level: str = "DEBUG"
    applicationinsights_connection_string: Any = None


class _Status(str, Enum):
    DONE = "DONE"


@pytest.fixture()
def restore_logging() -> Iterator[None]:
    root = logging.getLogger()
    saved_handlers = list(root.handlers)
    saved_level = root.level
    access = logging.getLogger("uvicorn.access")
    saved_access = (list(access.handlers), access.propagate, access.level)
    yield
    for handler in list(root.handlers):
        if handler not in saved_handlers:
            root.removeHandler(handler)
    for handler in saved_handlers:
        if handler not in root.handlers:
            root.addHandler(handler)
    root.setLevel(saved_level)
    access.handlers[:] = saved_access[0]
    access.propagate = saved_access[1]
    access.setLevel(saved_access[2])


@pytest.fixture()
def capture(restore_logging: None) -> io.StringIO:
    stream = io.StringIO()
    plog.configure_logging(_FakeSettings(), stream=stream)  # type: ignore[arg-type]
    return stream


def _lines(stream: io.StringIO) -> list[dict[str, Any]]:
    return [json.loads(line) for line in stream.getvalue().splitlines() if line.strip()]


def test_json_shape_has_fixed_fields(capture: io.StringIO) -> None:
    logging.getLogger("payshield.test").info("analysis completed")
    (entry,) = _lines(capture)
    assert entry["level"] == "INFO"
    assert entry["logger"] == "payshield.test"
    assert entry["message"] == "analysis completed"
    assert entry["service"] == "payshield-ai"
    assert entry["environment"] == "dev"
    assert "correlation_id" in entry
    stamp = datetime.fromisoformat(entry["timestamp"])
    assert stamp.utcoffset() is not None and stamp.utcoffset().total_seconds() == 0


def test_allowed_extras_are_emitted_and_typed(capture: io.StringIO) -> None:
    tenant_uid = str(uuid.uuid4())
    logging.getLogger("payshield.test").info(
        "done",
        extra={"tenant_uid": tenant_uid, "count": 12, "duration_ms": 35.5, "status": _Status.DONE, "event": "x"},
    )
    (entry,) = _lines(capture)
    assert entry["tenant_uid"] == tenant_uid
    assert entry["count"] == 12
    assert entry["duration_ms"] == 35.5
    assert entry["status"] == "DONE"
    assert entry["event"] == "x"
    assert "dropped_extra_count" not in entry


def test_every_allow_listed_key_passes(capture: io.StringIO) -> None:
    extras = {key: f"v-{key}" for key in plog.ALLOWED_EXTRA_KEYS}
    logging.getLogger("payshield.test").info("all keys", extra=extras)
    (entry,) = _lines(capture)
    for key, value in extras.items():
        assert entry[key] == value


def test_unknown_extras_are_dropped(capture: io.StringIO) -> None:
    logging.getLogger("payshield.test").warning(
        "suspicious",
        extra={"employee_name": "Tan Ah Kow", "salary": 8123, "email": "x@y.com", "company_uid": "c-1"},
    )
    raw = capture.getvalue()
    (entry,) = _lines(capture)
    assert "employee_name" not in entry and "salary" not in entry and "email" not in entry
    assert "Tan Ah Kow" not in raw and "8123" not in raw and "x@y.com" not in raw
    assert entry["company_uid"] == "c-1"
    assert entry["dropped_extra_count"] == 3


def test_message_scrubbing_masks_pii_and_money(capture: io.StringIO) -> None:
    logging.getLogger("payshield.test").info(
        "net %s for %s nric %s total %s version 1.2.0", 4567.89, "ann@example.com", "S1234567D", "12,345"
    )
    (entry,) = _lines(capture)
    message = entry["message"]
    assert "4567.89" not in message and "ann@example.com" not in message
    assert "S1234567D" not in message and "12,345" not in message
    assert "[email]" in message and "[nric]" in message and "[number]" in message
    # semantic versions are not money and must stay readable
    assert "1.2.0" in message


def test_scrub_text_truncates_long_text() -> None:
    scrubbed = plog.scrub_text("a" * 50, limit=10)
    assert scrubbed == "a" * 10 + "...[truncated]"


def test_correlation_id_from_context(capture: io.StringIO) -> None:
    token = plog.set_correlation_id("req-abc.123")
    try:
        logging.getLogger("payshield.test").info("inside")
        assert plog.get_correlation_id() == "req-abc.123"
    finally:
        plog.reset_correlation_id(token)
    logging.getLogger("payshield.test").info("outside")
    inside, outside = _lines(capture)
    assert inside["correlation_id"] == "req-abc.123"
    assert outside["correlation_id"] is None


def test_unsafe_correlation_id_is_replaced() -> None:
    token = plog.set_correlation_id('bad"id\n{"level":"CRITICAL"}')
    try:
        value = plog.get_correlation_id()
        assert value is not None and len(value) == 32 and value.isalnum()
    finally:
        plog.reset_correlation_id(token)
    assert plog.normalize_correlation_id("x" * 129) is None
    assert plog.normalize_correlation_id("   ") is None
    assert plog.normalize_correlation_id(None) is None
    assert plog.normalize_correlation_id(" ok-1 ") == "ok-1"


def test_set_correlation_id_without_value_generates_one() -> None:
    token = plog.set_correlation_id()
    try:
        assert plog.get_correlation_id() is not None
    finally:
        plog.reset_correlation_id(token)


def test_new_correlation_id_is_unique_and_does_not_bind() -> None:
    before = plog.get_correlation_id()
    first, second = plog.new_correlation_id(), plog.new_correlation_id()
    assert first != second and len(first) == 32
    assert plog.get_correlation_id() == before


def test_explicit_correlation_id_extra_overrides_context(capture: io.StringIO) -> None:
    token = plog.set_correlation_id("ctx-1")
    try:
        logging.getLogger("payshield.test").info("msg", extra={"correlation_id": "msg-2"})
    finally:
        plog.reset_correlation_id(token)
    (entry,) = _lines(capture)
    assert entry["correlation_id"] == "msg-2"


def test_correlation_id_is_isolated_between_tasks(capture: io.StringIO) -> None:
    async def handle(cid: str) -> None:
        plog.set_correlation_id(cid)
        await asyncio.sleep(0)
        logging.getLogger("payshield.test").info("task", extra={"event": cid})

    async def main() -> None:
        await asyncio.gather(handle("task-a"), handle("task-b"))

    asyncio.run(main())
    # asyncio emits its own debug line on windows; only this test's logger matters
    entries = [e for e in _lines(capture) if e["logger"] == "payshield.test"]
    assert len(entries) == 2
    for entry in entries:
        assert entry["correlation_id"] == entry["event"]


def test_exception_logging_has_no_locals(capture: io.StringIO) -> None:
    def compute() -> None:
        secret_amount = 98765.43  # noqa: F841 - must never be rendered
        holder_email = "pay@corp.example"  # noqa: F841
        raise ValueError("bad row for someone@corp.example amount 1234.56")

    try:
        compute()
    except ValueError:
        logging.getLogger("payshield.test").exception("analysis failed", extra={"error_code": "ANALYSIS_FAILED"})
    raw = capture.getvalue()
    (entry,) = _lines(capture)
    assert entry["level"] == "ERROR"
    assert entry["error_code"] == "ANALYSIS_FAILED"
    exception = entry["exception"]
    assert exception["type"] == "builtins.ValueError"
    assert "someone@corp.example" not in exception["message"] and "1234.56" not in exception["message"]
    assert any(frame["function"] == "compute" for frame in exception["stack"])
    assert "98765.43" not in raw.replace("secret_amount = 98765.43", "")
    assert "pay@corp.example" not in raw.replace('holder_email = "pay@corp.example"', "")
    assert all(set(frame) == {"file", "line", "function", "code"} for frame in exception["stack"])


def test_log_level_is_applied_and_invalid_level_falls_back(restore_logging: None) -> None:
    stream = io.StringIO()
    plog.configure_logging(_FakeSettings(log_level="warning"), stream=stream)  # type: ignore[arg-type]
    assert logging.getLogger().level == logging.WARNING
    logging.getLogger("payshield.test").info("hidden")
    assert stream.getvalue() == ""
    plog.configure_logging(_FakeSettings(log_level="nonsense"), stream=stream)  # type: ignore[arg-type]
    assert logging.getLogger().level == logging.INFO


def test_configure_logging_is_idempotent(restore_logging: None) -> None:
    first, second = io.StringIO(), io.StringIO()
    plog.configure_logging(_FakeSettings(), stream=first)  # type: ignore[arg-type]
    plog.configure_logging(_FakeSettings(), stream=second)  # type: ignore[arg-type]
    own = [h for h in logging.getLogger().handlers if getattr(h, "_payshield_handler", False)]
    assert len(own) == 1
    logging.getLogger("payshield.test").info("once")
    assert first.getvalue() == ""
    assert len(_lines(second)) == 1


def test_uvicorn_access_log_is_silenced(capture: io.StringIO) -> None:
    logging.getLogger("uvicorn.access").info('1.2.3.4 - "GET /x?q=1 HTTP/1.1" 200')
    logging.getLogger("uvicorn.error").info("started")
    entries = _lines(capture)
    assert [e["logger"] for e in entries] == ["uvicorn.error"]


def test_works_with_real_settings_without_azure_monitor(restore_logging: None) -> None:
    stream = io.StringIO()
    settings = Settings(environment="qa", service_name="payshield-ai", log_level="INFO")
    enabled = plog.configure_logging(settings, stream=stream)
    assert enabled is False
    logging.getLogger("payshield.test").info("hello")
    (entry,) = _lines(stream)
    assert entry["environment"] == "qa"


def test_azure_monitor_not_enabled_when_package_missing(
    restore_logging: None, monkeypatch: pytest.MonkeyPatch
) -> None:
    # a None entry in sys.modules makes the import fail exactly as if the package were not installed
    monkeypatch.setitem(sys.modules, "azure.monitor.opentelemetry", None)
    monkeypatch.setattr(plog, "_azure_monitor_enabled", False)
    settings = _FakeSettings(applicationinsights_connection_string=SecretStr("InstrumentationKey=00000000"))
    assert plog.configure_logging(settings, stream=io.StringIO()) is False  # type: ignore[arg-type]


def test_azure_monitor_enabled_when_available(restore_logging: None, monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[str] = []
    exported: list[logging.LogRecord] = []

    class _ExportHandler(logging.Handler):
        def emit(self, record: logging.LogRecord) -> None:
            exported.append(record)

    def fake_configure(connection_string: str) -> None:
        calls.append(connection_string)
        logging.getLogger().addHandler(_ExportHandler())

    fake_module = type(sys)("azure.monitor.opentelemetry")
    fake_module.configure_azure_monitor = fake_configure  # type: ignore[attr-defined]
    monkeypatch.setitem(sys.modules, "azure.monitor.opentelemetry", fake_module)
    monkeypatch.setattr(plog, "_azure_monitor_enabled", False)
    monkeypatch.delenv("OTEL_SERVICE_NAME", raising=False)
    settings = _FakeSettings(applicationinsights_connection_string=SecretStr("InstrumentationKey=abc"))
    try:
        assert plog.configure_logging(settings, stream=io.StringIO()) is True  # type: ignore[arg-type]
        assert calls == ["InstrumentationKey=abc"]
        # second configuration must not install the exporter twice
        assert plog.configure_logging(settings, stream=io.StringIO()) is True  # type: ignore[arg-type]
        assert len(calls) == 1
        logging.getLogger("payshield.test").info("exported", extra={"salary": 1, "job_uid": "j-1"})
        (record,) = exported
        assert not hasattr(record, "salary")
        assert getattr(record, "job_uid") == "j-1"
        assert getattr(record, "service") == "payshield-ai"
    finally:
        for handler in list(logging.getLogger().handlers):
            if isinstance(handler, _ExportHandler):
                logging.getLogger().removeHandler(handler)


def test_azure_monitor_skipped_without_connection_string(
    restore_logging: None, monkeypatch: pytest.MonkeyPatch
) -> None:
    def fail(**_: Any) -> None:
        raise AssertionError("must not be called")

    fake_module = type(sys)("azure.monitor.opentelemetry")
    fake_module.configure_azure_monitor = fail  # type: ignore[attr-defined]
    monkeypatch.setitem(sys.modules, "azure.monitor.opentelemetry", fake_module)
    monkeypatch.setattr(plog, "_azure_monitor_enabled", False)
    assert plog.configure_logging(_FakeSettings(applicationinsights_connection_string=SecretStr("")),
                                  stream=io.StringIO()) is False  # type: ignore[arg-type]


def test_azure_monitor_failure_keeps_stdout_logging(
    restore_logging: None, monkeypatch: pytest.MonkeyPatch
) -> None:
    def broken(connection_string: str) -> None:
        raise RuntimeError("boom")

    fake_module = type(sys)("azure.monitor.opentelemetry")
    fake_module.configure_azure_monitor = broken  # type: ignore[attr-defined]
    monkeypatch.setitem(sys.modules, "azure.monitor.opentelemetry", fake_module)
    monkeypatch.setattr(plog, "_azure_monitor_enabled", False)
    stream = io.StringIO()
    settings = _FakeSettings(applicationinsights_connection_string="InstrumentationKey=abc")
    assert plog.configure_logging(settings, stream=stream) is False  # type: ignore[arg-type]
    (entry,) = _lines(stream)
    assert entry["error_code"] == "AZURE_MONITOR_INIT"


def test_module_imports_standalone() -> None:
    # the module must not pull in pydantic/fastapi/app code so scripts and the worker can import it first
    code = (
        "import sys; import app.core.logging as m; "
        "bad = [n for n in ('pydantic', 'fastapi', 'app.core.config') if n in sys.modules]; "
        "print(','.join(bad))"
    )
    result = subprocess.run(
        [sys.executable, "-I", "-c", f"import sys; sys.path.insert(0, {str(PACKAGE_ROOT)!r}); {code}"],
        capture_output=True,
        text=True,
        timeout=60,
        check=True,
    )
    assert result.stdout.strip() == ""
