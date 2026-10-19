"""Structured JSON logging, correlation ids and optional Azure Monitor export.

Every log line is one JSON object on stdout (Container Apps ships stdout to Log Analytics) with
``timestamp`` (UTC ISO 8601), ``level``, ``logger``, ``message``, ``correlation_id``, ``service`` and
``environment``. ``extra={...}`` fields are passed through only when their key is in
``ALLOWED_EXTRA_KEYS``; anything else is dropped so a stray ``extra={"employee": ...}`` can never leak
payroll values or personal data into logs. Messages and exception texts are also scrubbed of e-mail
addresses, NRIC/FIN numbers and money-like decimals as defence in depth.

This module only imports the standard library so it can be imported before (and without) the rest of
the application, e.g. by the worker entry point or by scripts.
"""

from __future__ import annotations

import json
import logging
import os
import re
import sys
import traceback
import uuid
from contextvars import ContextVar, Token
from datetime import datetime, timezone
from enum import Enum
from typing import IO, TYPE_CHECKING, Any, Final

if TYPE_CHECKING:
    from app.core.config import Settings

__all__ = [
    "ALLOWED_EXTRA_KEYS",
    "AllowListFilter",
    "JsonFormatter",
    "configure_logging",
    "correlation_id_var",
    "get_correlation_id",
    "new_correlation_id",
    "normalize_correlation_id",
    "reset_correlation_id",
    "scrub_text",
    "set_correlation_id",
]

ALLOWED_EXTRA_KEYS: Final[frozenset[str]] = frozenset(
    {
        "tenant_uid",
        "company_uid",
        "analysis_uid",
        "pay_run_uid",
        "model_uid",
        "job_uid",
        "status",
        "count",
        "duration_ms",
        "event",
        "error_code",
        "rule_id",
        "detector",
        "ml_status",
        "path",
        "method",
        "status_code",
    }
)

# fields this module adds to every record itself; they survive the allow-list filter so a record that
# passes through several handlers (stdout + azure monitor) is cleaned once and keeps its markers
_RESERVED_KEYS: Final[frozenset[str]] = frozenset(
    {"correlation_id", "service", "environment", "dropped_extra_count", "_payshield_scrubbed"}
)

# attributes every LogRecord has; anything else on a record came from ``extra=``
_STANDARD_RECORD_ATTRS: Final[frozenset[str]] = frozenset(
    vars(logging.LogRecord("", logging.INFO, "", 0, "", None, None)).keys()
) | {"message", "asctime", "taskName"}

_MARKER_ATTR: Final[str] = "_payshield_handler"
_MAX_MESSAGE_CHARS: Final[int] = 4000
_MAX_EXCEPTION_MESSAGE_CHARS: Final[int] = 500
_MAX_CORRELATION_ID_CHARS: Final[int] = 128
_CORRELATION_ID_PATTERN: Final[re.Pattern[str]] = re.compile(r"^[A-Za-z0-9._:\-]{1,128}$")

# order matters: e-mails before numbers so the local part is replaced as a whole
_SCRUB_PATTERNS: Final[tuple[tuple[re.Pattern[str], str], ...]] = (
    (re.compile(r"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"), "[email]"),
    (re.compile(r"\b[STFGMstfgm]\d{7}[A-Za-z]\b"), "[nric]"),
    (re.compile(r"(?<![\w.])-?\d{1,3}(?:,\d{3})+(?:\.\d+)?(?![\w.])"), "[number]"),
    (re.compile(r"(?<![\w.\-])-?\d+\.\d{1,4}(?![\w.])"), "[number]"),
)

correlation_id_var: ContextVar[str | None] = ContextVar("payshield_correlation_id", default=None)

_azure_monitor_enabled = False


def new_correlation_id() -> str:
    """Fresh correlation id (uuid4 hex form). Does not change the current context."""
    return uuid.uuid4().hex


def normalize_correlation_id(value: str | None) -> str | None:
    """Return ``value`` if it is a safe correlation id, else None.

    incoming ids come from request headers or message properties, so they are restricted to a short
    token alphabet before they are echoed into logs and responses.
    """
    if value is None:
        return None
    candidate = value.strip()
    if not candidate or len(candidate) > _MAX_CORRELATION_ID_CHARS:
        return None
    return candidate if _CORRELATION_ID_PATTERN.fullmatch(candidate) else None


def set_correlation_id(value: str | None = None) -> Token[str | None]:
    """Bind a correlation id to the current context; an absent or unsafe value gets a new id.

    returns the contextvar token so callers (middleware, worker) can restore the previous value.
    """
    return correlation_id_var.set(normalize_correlation_id(value) or new_correlation_id())


def reset_correlation_id(token: Token[str | None]) -> None:
    correlation_id_var.reset(token)


def get_correlation_id() -> str | None:
    return correlation_id_var.get()


def scrub_text(text: str, limit: int = _MAX_MESSAGE_CHARS) -> str:
    """Mask e-mails, NRIC/FIN and money-like numbers, then truncate.

    log messages are written by developers and should not contain such values; this is the safety net
    for messages and exception texts that interpolate data by accident (e.g. driver error details).
    """
    scrubbed = text
    for pattern, replacement in _SCRUB_PATTERNS:
        scrubbed = pattern.sub(replacement, scrubbed)
    if len(scrubbed) > limit:
        return scrubbed[:limit] + "...[truncated]"
    return scrubbed


def _json_safe(value: Any) -> Any:
    if value is None or isinstance(value, (bool, int, float, str)):
        return value
    if isinstance(value, Enum):
        return _json_safe(value.value)
    return str(value)


def _record_correlation_id(record: logging.LogRecord) -> str | None:
    """Explicit ``extra={"correlation_id": ...}`` (validated) wins over the context value."""
    explicit = getattr(record, "correlation_id", None)
    return normalize_correlation_id(explicit if isinstance(explicit, str) else None) or get_correlation_id()


def _extra_keys(record: logging.LogRecord) -> list[str]:
    return [key for key in vars(record) if key not in _STANDARD_RECORD_ATTRS and key not in _RESERVED_KEYS]


class AllowListFilter(logging.Filter):
    """Handler filter that enforces the extra-key allow-list on the record itself.

    the json formatter already ignores unknown keys, but other handlers (azure monitor exports every
    non-standard record attribute) would not, so the record is cleaned before any handler sees it.
    the filter also stamps correlation id / service / environment and replaces the message with its
    scrubbed rendering.
    """

    def __init__(self, service: str, environment: str) -> None:
        super().__init__()
        self._service = service
        self._environment = environment

    def filter(self, record: logging.LogRecord) -> bool:
        dropped = 0
        for key in _extra_keys(record):
            if key not in ALLOWED_EXTRA_KEYS:
                delattr(record, key)
                dropped += 1
        if dropped:
            record.dropped_extra_count = dropped
        record.correlation_id = _record_correlation_id(record)
        record.service = self._service
        record.environment = self._environment
        if not getattr(record, "_payshield_scrubbed", False):
            record.msg = scrub_text(record.getMessage())
            record.args = None
            record._payshield_scrubbed = True
        return True


def _format_exception(exc_info: Any) -> dict[str, Any] | None:
    """Exception type, scrubbed message and stack frames (file, line, function, source line).

    frame locals are never rendered: ``traceback.format_exception`` without ``capture_locals`` only
    walks code locations, so salaries held in local variables cannot reach the log.
    """
    if not exc_info or exc_info is True:
        return None
    exc_type, exc_value, exc_tb = exc_info
    if exc_type is None:
        return None
    frames = traceback.extract_tb(exc_tb, limit=30)
    return {
        "type": f"{exc_type.__module__}.{exc_type.__qualname__}",
        "message": scrub_text(str(exc_value), _MAX_EXCEPTION_MESSAGE_CHARS),
        "stack": [
            {"file": frame.filename, "line": frame.lineno, "function": frame.name, "code": frame.line or ""}
            for frame in frames
        ],
    }


class JsonFormatter(logging.Formatter):
    """One JSON object per record with the fixed field set plus allow-listed extras."""

    def __init__(self, service: str, environment: str) -> None:
        super().__init__()
        self._service = service
        self._environment = environment

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": datetime.fromtimestamp(record.created, tz=timezone.utc).isoformat(timespec="milliseconds"),
            "level": record.levelname,
            "logger": record.name,
            "message": scrub_text(record.getMessage()),
            "correlation_id": _record_correlation_id(record),
            "service": self._service,
            "environment": self._environment,
        }
        for key in sorted(_extra_keys(record)):
            if key in ALLOWED_EXTRA_KEYS:
                payload[key] = _json_safe(getattr(record, key))
        dropped = getattr(record, "dropped_extra_count", None)
        if dropped:
            payload["dropped_extra_count"] = dropped
        exception = _format_exception(record.exc_info)
        if exception is not None:
            payload["exception"] = exception
        if record.stack_info:
            payload["stack_info"] = record.stack_info
        return json.dumps(payload, ensure_ascii=False, separators=(",", ":"))


def _secret_value(value: Any) -> str:
    if value is None:
        return ""
    getter = getattr(value, "get_secret_value", None)
    return str(getter() if callable(getter) else value).strip()


def _resolve_level(name: str) -> int:
    level = logging.getLevelName(str(name).strip().upper())
    return level if isinstance(level, int) else logging.INFO


def _remove_own_handlers(root: logging.Logger) -> None:
    for handler in list(root.handlers):
        if getattr(handler, _MARKER_ATTR, False):
            root.removeHandler(handler)
            handler.close()


def _tame_library_loggers() -> None:
    """Route third-party loggers through the root json handler and silence chatty/sensitive ones."""
    for name in ("uvicorn", "uvicorn.error"):
        lib_logger = logging.getLogger(name)
        lib_logger.handlers.clear()
        lib_logger.propagate = True
    # uvicorn access lines carry client ip and full query strings; request logging is done by the
    # app middleware with allow-listed fields (path, method, status_code, duration_ms) instead
    access = logging.getLogger("uvicorn.access")
    access.handlers.clear()
    access.propagate = False
    access.setLevel(logging.WARNING)
    # azure sdk http logging prints request urls and headers at info level
    for name in ("azure", "azure.core.pipeline.policies.http_logging_policy", "httpx", "httpcore", "openai"):
        logging.getLogger(name).setLevel(logging.WARNING)


def _configure_azure_monitor(connection_string: str, service: str, environment: str, root: logging.Logger) -> bool:
    """Enable OpenTelemetry export to Application Insights when the distro is installed.

    the package is optional (not in requirements); without it the service still logs json to stdout,
    which container apps forwards to log analytics.
    """
    global _azure_monitor_enabled
    if _azure_monitor_enabled:
        return True
    if not connection_string:
        return False
    try:
        from azure.monitor.opentelemetry import configure_azure_monitor
    except ImportError:
        return False
    # the distro reads the cloud role name from OTEL_SERVICE_NAME; keep an explicit value if one is set
    os.environ.setdefault("OTEL_SERVICE_NAME", service)
    try:
        configure_azure_monitor(connection_string=connection_string)
    except Exception:  # export is best-effort; logging to stdout must keep working
        logging.getLogger(__name__).warning(
            "azure monitor configuration failed", extra={"event": "telemetry_init", "error_code": "AZURE_MONITOR_INIT"}
        )
        return False
    for handler in root.handlers:
        if not any(isinstance(f, AllowListFilter) for f in handler.filters):
            handler.addFilter(AllowListFilter(service, environment))
    _azure_monitor_enabled = True
    return True


def configure_logging(settings: "Settings", stream: IO[str] | None = None) -> bool:
    """Install the json handler on the root logger (idempotent).

    ``stream`` defaults to stdout and exists for tests. returns True when azure monitor export was
    enabled. safe to call more than once (app factory and worker both call it): previously installed
    payshield handlers are replaced, foreign handlers are left alone.
    """
    service = str(getattr(settings, "service_name", "payshield-ai"))
    environment = str(getattr(settings, "environment", "local"))
    root = logging.getLogger()
    _remove_own_handlers(root)

    handler = logging.StreamHandler(stream if stream is not None else sys.stdout)
    handler.setFormatter(JsonFormatter(service, environment))
    handler.addFilter(AllowListFilter(service, environment))
    setattr(handler, _MARKER_ATTR, True)
    root.addHandler(handler)
    root.setLevel(_resolve_level(getattr(settings, "log_level", "INFO")))
    _tame_library_loggers()

    connection_string = _secret_value(getattr(settings, "applicationinsights_connection_string", None))
    return _configure_azure_monitor(connection_string, service, environment, root)
