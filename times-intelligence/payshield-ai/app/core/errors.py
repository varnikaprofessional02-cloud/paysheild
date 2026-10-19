"""Error model rendered as RFC 7807 problem+json. 5xx never exposes internal exception text."""

from __future__ import annotations

from starlette.responses import JSONResponse


class PayShieldError(Exception):
    status = 500
    title = "Internal error"

    def __init__(self, code: str, message: str, detail: str | None = None):
        super().__init__(message)
        self.code, self.message, self.detail = code, message, detail


class Unauthorized(PayShieldError):
    status, title = 401, "Unauthorized"


class Forbidden(PayShieldError):
    status, title = 403, "Forbidden"


class NotFound(PayShieldError):
    status, title = 404, "Not found"


class Conflict(PayShieldError):
    status, title = 409, "Conflict"


class ValidationFailed(PayShieldError):
    status, title = 422, "Validation failed"


class DependencyUnavailable(PayShieldError):
    status, title = 503, "Dependency unavailable"


def problem_response(err: PayShieldError, correlation_id: str | None) -> JSONResponse:
    detail = err.message if err.status < 500 else "The request could not be completed."
    return JSONResponse(
        {"type": f"https://payshield/errors/{err.code}", "title": err.title, "status": err.status, "detail": detail,
         "code": err.code, "correlationId": correlation_id},
        status_code=err.status, media_type="application/problem+json")
