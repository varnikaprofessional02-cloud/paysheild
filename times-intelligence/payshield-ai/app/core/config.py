"""Service configuration. Every value can be set with an environment variable prefixed ``PAYSHIELD_``
(nested keys use ``__``, e.g. ``PAYSHIELD_DB__HOST``). Secrets come from the environment, which in Azure
is populated from Key Vault references; nothing secret has a non-empty default.
"""

from __future__ import annotations

from functools import lru_cache
from typing import Literal

from pydantic import BaseModel, Field, SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class DatabaseSettings(BaseModel):
    host: str = "localhost"
    port: int = 5432
    username: str = "payshield_svc"
    password: SecretStr = SecretStr("")
    sslmode: str = "require"
    # use Entra (managed identity) tokens as the password instead of a static secret
    use_entra_auth: bool = False
    connect_timeout_seconds: int = 10
    statement_timeout_ms: int = 120_000
    pool_min_size: int = 0
    pool_max_size: int = 5
    # tenant-store database holding tenant.tenant / tenant.tenant_identity_provider
    tenant_store_database: str = "times-tenantstore-dev"
    tenant_cache_ttl_seconds: int = 300


class KeycloakSettings(BaseModel):
    # e.g. https://auth.example.com  (realm path is appended per tenant)
    authority: str = ""
    # accepted audiences; empty = do not check audience (matches existing services, see assessment 1.4)
    audiences: list[str] = Field(default_factory=list)
    jwks_cache_ttl_seconds: int = 600
    clock_skew_seconds: int = 30
    require_https: bool = True
    # existing APIs read the Times user uid from "sub" (CurrentUserProvider: NameIdentifier ?? sub);
    # the value must also exist in security."user".uid or the request is rejected
    user_uid_claims: list[str] = Field(default_factory=lambda: ["sub"])


class ServiceAuthSettings(BaseModel):
    mode: Literal["entra", "shared_secret", "disabled"] = "entra"
    entra_tenant_id: str = ""
    entra_audience: str = ""  # e.g. api://payshield-ai
    allowed_app_ids: list[str] = Field(default_factory=list)
    required_role: str = "PayShield.Service"
    # dev only; refused when environment == production
    shared_secret: SecretStr = SecretStr("")


class StorageSettings(BaseModel):
    backend: Literal["local", "azure_blob"] = "local"
    local_root: str = "./.payshield-models"
    blob_account_url: str = ""  # https://<account>.blob.core.windows.net (managed identity)
    blob_connection_string: SecretStr = SecretStr("")  # alternative to account_url, dev only
    blob_container: str = "payshield-models"
    model_cache_max_entries: int = 64


class MessagingSettings(BaseModel):
    execution_mode: Literal["inline", "servicebus"] = "inline"
    servicebus_fully_qualified_namespace: str = ""  # managed identity
    servicebus_connection_string: SecretStr = SecretStr("")  # alternative, dev only
    analysis_queue: str = "payshield-analysis-requested"
    training_queue: str = "payshield-training-requested"
    max_delivery_attempts: int = 5


class LlmSettings(BaseModel):
    provider: Literal["azure_openai", "disabled"] = "disabled"
    azure_endpoint: str = ""  # https://<resource>.openai.azure.com
    azure_deployment: str = ""
    api_version: str = "2024-10-21"
    api_key: SecretStr = SecretStr("")  # empty = use managed identity (DefaultAzureCredential)
    timeout_seconds: float = 30.0
    max_tool_rounds: int = 4
    max_output_tokens: int = 900
    temperature: float = 0.1


class MlSettings(BaseModel):
    feature_schema_version: str = "1"
    min_training_observations: int = 150
    min_training_periods: int = 6
    min_history_periods_for_scoring: int = 3
    history_window_periods: int = 12
    validation_fraction: float = 0.2
    isolation_forest_estimators: int = 300
    isolation_forest_max_samples: int | str = "auto"
    random_state: int = 42
    # activation gate (docs/02_ML_DESIGN.md#activation)
    gate_min_average_precision: float = 0.30
    gate_min_recall_at_alert: float = 0.30
    gate_max_clean_alert_rate: float = 0.10
    gate_max_ap_regression: float = 0.02
    alert_percentile: float = 97.0
    expected_value_model_enabled: bool = True
    expected_value_min_improvement: float = 0.05


class SweeperSettings(BaseModel):
    lookback_days: int = 45
    max_runs_per_tenant: int = 200


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="PAYSHIELD_", env_nested_delimiter="__", env_file=None, extra="ignore")

    environment: Literal["local", "dev", "qa", "sit", "production"] = "local"
    service_name: str = "payshield-ai"
    log_level: str = "INFO"
    applicationinsights_connection_string: SecretStr = SecretStr("")

    db: DatabaseSettings = Field(default_factory=DatabaseSettings)
    keycloak: KeycloakSettings = Field(default_factory=KeycloakSettings)
    service_auth: ServiceAuthSettings = Field(default_factory=ServiceAuthSettings)
    storage: StorageSettings = Field(default_factory=StorageSettings)
    messaging: MessagingSettings = Field(default_factory=MessagingSettings)
    llm: LlmSettings = Field(default_factory=LlmSettings)
    ml: MlSettings = Field(default_factory=MlSettings)
    sweeper: SweeperSettings = Field(default_factory=SweeperSettings)

    # function code / permission that gates PayShield (assessment section 8, question 3)
    pay_function_code: str = "PAY"
    view_permission: str = "View"
    manage_permission: str = "Edit"  # training, activation, rollback, feedback
    data_security_module: str = "Pay"

    @model_validator(mode="after")
    def _guard_production(self) -> "Settings":
        if self.environment == "production":
            if self.service_auth.mode != "entra":
                raise ValueError("service_auth.mode must be 'entra' in production")
            if self.storage.backend != "azure_blob":
                raise ValueError("storage.backend must be 'azure_blob' in production")
            if not self.keycloak.authority.startswith("https://"):
                raise ValueError("keycloak.authority must be https in production")
        return self

    @property
    def is_production(self) -> bool:
        return self.environment == "production"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
