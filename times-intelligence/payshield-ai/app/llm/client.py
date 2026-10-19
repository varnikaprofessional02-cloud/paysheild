"""LLM client abstraction for the private assistant and explanation services.

The only production provider is Azure OpenAI (a private deployment in the customer's Azure tenant). Every
provider failure surfaces as ``LlmUnavailable`` so the services can fall back to deterministic answers;
nothing above this module ever sees an SDK exception type.
"""

from __future__ import annotations

import json
import logging
import time
from dataclasses import dataclass, field
from typing import Any, Callable, Protocol

import httpx
import openai
from azure import identity as azure_identity

from app.core.config import LlmSettings

logger = logging.getLogger(__name__)

COGNITIVE_SERVICES_SCOPE = "https://cognitiveservices.azure.com/.default"
SDK_MAX_RETRIES = 2

try:  # the openai sdk may vendor its own httpx fork; its errors must map to LlmUnavailable too
    import httpx2 as _httpx2  # type: ignore[import-not-found]

    _TRANSPORT_ERRORS: tuple[type[BaseException], ...] = (httpx.HTTPError, _httpx2.HTTPError)
except ImportError:  # pragma: no cover - depends on the installed sdk build
    _TRANSPORT_ERRORS = (httpx.HTTPError,)


class LlmUnavailable(Exception):
    """The provider is disabled, misconfigured, unreachable, throttled or timed out."""

    def __init__(self, reason: str, message: str | None = None) -> None:
        super().__init__(message or reason)
        self.reason = reason  # DISABLED | NOT_CONFIGURED | TIMEOUT | RATE_LIMITED | PROVIDER_ERROR | BAD_RESPONSE


@dataclass(frozen=True)
class ToolCall:
    id: str
    name: str
    arguments_json: str


@dataclass(frozen=True)
class LlmResponse:
    content: str | None
    tool_calls: list[ToolCall] = field(default_factory=list)
    model: str | None = None
    finish_reason: str | None = None


class LlmClient(Protocol):
    @property
    def model_name(self) -> str | None: ...

    def complete(
        self,
        messages: list[dict[str, Any]],
        tools: list[dict[str, Any]] | None = None,
        tool_choice: str = "auto",
        max_tokens: int = 900,
        temperature: float = 0.1,
    ) -> LlmResponse: ...


class DisabledLlmClient:
    """Used when no provider is configured; callers take their deterministic fallback path."""

    def __init__(self, reason: str = "DISABLED") -> None:
        self._reason = reason

    @property
    def model_name(self) -> str | None:
        return None

    def complete(
        self,
        messages: list[dict[str, Any]],
        tools: list[dict[str, Any]] | None = None,
        tool_choice: str = "auto",
        max_tokens: int = 900,
        temperature: float = 0.1,
    ) -> LlmResponse:
        raise LlmUnavailable(self._reason, "llm provider is disabled")


class AzureOpenAiClient:
    """Chat completions against an Azure OpenAI deployment (api key or managed identity)."""

    def __init__(self, settings: LlmSettings, *, sdk_client: Any | None = None) -> None:
        self._settings = settings
        self._deployment = settings.azure_deployment
        self.auth_mode = "api_key" if settings.api_key.get_secret_value() else "managed_identity"
        self._client = sdk_client if sdk_client is not None else self._create_sdk_client(settings)

    @property
    def model_name(self) -> str | None:
        return self._deployment or None

    @staticmethod
    def _create_sdk_client(settings: LlmSettings) -> Any:
        common: dict[str, Any] = {
            "azure_endpoint": settings.azure_endpoint,
            "api_version": settings.api_version,
            "azure_deployment": settings.azure_deployment,
            "timeout": settings.timeout_seconds,
            "max_retries": SDK_MAX_RETRIES,
        }
        api_key = settings.api_key.get_secret_value()
        if api_key:
            return openai.AzureOpenAI(api_key=api_key, **common)
        # managed identity in azure, developer login locally; no secret is stored anywhere
        provider = _managed_identity_token_provider()
        return openai.AzureOpenAI(azure_ad_token_provider=provider, **common)

    def complete(
        self,
        messages: list[dict[str, Any]],
        tools: list[dict[str, Any]] | None = None,
        tool_choice: str = "auto",
        max_tokens: int = 900,
        temperature: float = 0.1,
    ) -> LlmResponse:
        request: dict[str, Any] = {
            "model": self._deployment,
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": temperature,
        }
        if tools:
            request["tools"] = tools
            request["tool_choice"] = tool_choice
        started = time.perf_counter()
        try:
            completion = self._client.chat.completions.create(**request)
        except Exception as exc:  # noqa: BLE001 - every provider failure becomes LlmUnavailable
            raise _map_error(exc) from exc
        finally:
            logger.info(
                "llm completion finished",
                extra={"llm_deployment": self._deployment, "duration_ms": int((time.perf_counter() - started) * 1000)},
            )
        return _parse_completion(completion)


def _managed_identity_token_provider() -> Callable[[], str]:
    credential = azure_identity.DefaultAzureCredential()
    return azure_identity.get_bearer_token_provider(credential, COGNITIVE_SERVICES_SCOPE)


def _map_error(exc: Exception) -> LlmUnavailable:
    if isinstance(exc, LlmUnavailable):
        return exc
    if isinstance(exc, openai.APITimeoutError) or isinstance(exc, TimeoutError):
        return LlmUnavailable("TIMEOUT", "llm request timed out")
    if isinstance(exc, openai.RateLimitError):
        return LlmUnavailable("RATE_LIMITED", "llm provider throttled the request")
    if isinstance(exc, (openai.OpenAIError, *_TRANSPORT_ERRORS, ConnectionError)):
        # the sdk message can echo request content, so only the exception type is kept
        return LlmUnavailable("PROVIDER_ERROR", f"llm provider error: {type(exc).__name__}")
    if isinstance(exc, (azure_identity.CredentialUnavailableError, _azure_auth_error())):
        return LlmUnavailable("NOT_CONFIGURED", f"llm credential error: {type(exc).__name__}")
    return LlmUnavailable("PROVIDER_ERROR", f"unexpected llm client error: {type(exc).__name__}")


def _azure_auth_error() -> type[BaseException]:
    from azure.core.exceptions import ClientAuthenticationError

    return ClientAuthenticationError


def _parse_completion(completion: Any) -> LlmResponse:
    choices = getattr(completion, "choices", None) or []
    if not choices:
        raise LlmUnavailable("BAD_RESPONSE", "llm returned no choices")
    choice = choices[0]
    message = getattr(choice, "message", None)
    if message is None:
        raise LlmUnavailable("BAD_RESPONSE", "llm returned no message")
    calls = [_parse_tool_call(tc) for tc in (getattr(message, "tool_calls", None) or [])]
    return LlmResponse(
        content=getattr(message, "content", None),
        tool_calls=[c for c in calls if c is not None],
        model=getattr(completion, "model", None),
        finish_reason=getattr(choice, "finish_reason", None),
    )


def _parse_tool_call(raw: Any) -> ToolCall | None:
    function = getattr(raw, "function", None)
    if function is None or not getattr(function, "name", None):
        return None
    arguments = getattr(function, "arguments", None)
    if not isinstance(arguments, str):
        arguments = json.dumps(arguments or {})
    return ToolCall(id=str(getattr(raw, "id", "") or ""), name=str(function.name), arguments_json=arguments)


def build_llm_client(settings: LlmSettings) -> LlmClient:
    """Factory used by the api/worker wiring. A half-configured provider disables the assistant LLM
    (deterministic fallback keeps working) instead of failing the whole service at startup."""
    if settings.provider != "azure_openai":
        return DisabledLlmClient("DISABLED")
    if not settings.azure_endpoint.startswith("https://") or not settings.azure_deployment:
        logger.warning("azure openai provider selected but endpoint/deployment not configured; llm disabled")
        return DisabledLlmClient("NOT_CONFIGURED")
    return AzureOpenAiClient(settings)
