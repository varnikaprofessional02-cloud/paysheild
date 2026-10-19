"""Per-database psycopg connection pools. Database names come only from the tenant store."""

from __future__ import annotations

import re
import threading
from collections import OrderedDict
from contextlib import contextmanager
from typing import Iterator

import psycopg
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

from app.core.config import DatabaseSettings

_DB_NAME = re.compile(r"^[A-Za-z0-9_\-]{1,63}$")
_ENTRA_SCOPE = "https://ossrdbms-aad.database.windows.net/.default"


class ConnectionManager:
    def __init__(self, settings: DatabaseSettings, max_pools: int = 50):
        self.s = settings
        self._pools: OrderedDict[str, ConnectionPool] = OrderedDict()
        self._lock = threading.Lock()
        self._max = max_pools
        self._credential = None

    def _password(self) -> str:
        if not self.s.use_entra_auth:
            return self.s.password.get_secret_value()
        if self._credential is None:
            from azure.identity import DefaultAzureCredential

            self._credential = DefaultAzureCredential()
        return self._credential.get_token(_ENTRA_SCOPE).token

    def _conninfo(self, db: str) -> str:
        return psycopg.conninfo.make_conninfo(
            host=self.s.host, port=self.s.port, dbname=db, user=self.s.username, sslmode=self.s.sslmode,
            connect_timeout=self.s.connect_timeout_seconds, application_name="payshield-ai",
            options=f"-c statement_timeout={self.s.statement_timeout_ms}")

    def _pool(self, db: str) -> ConnectionPool:
        if not _DB_NAME.match(db):
            raise ValueError("invalid database name")
        with self._lock:
            pool = self._pools.get(db)
            if pool is None:
                kwargs = {"row_factory": dict_row}
                if self.s.password.get_secret_value():
                    kwargs["password"] = self.s.password.get_secret_value()
                pool = ConnectionPool(self._conninfo(db), min_size=self.s.pool_min_size, max_size=self.s.pool_max_size,
                                      kwargs=kwargs, open=True, reconnect_timeout=30)
                self._pools[db] = pool
                while len(self._pools) > self._max:
                    self._pools.popitem(last=False)[1].close()
            self._pools.move_to_end(db)
            return pool

    @contextmanager
    def connection(self, db: str) -> Iterator[psycopg.Connection]:
        if self.s.use_entra_auth:
            # tokens expire: open a direct connection with a fresh token instead of pooling stale credentials
            if not _DB_NAME.match(db):
                raise ValueError("invalid database name")
            with psycopg.connect(self._conninfo(db), password=self._password(), row_factory=dict_row) as conn:
                yield conn
            return
        with self._pool(db).connection() as conn:
            yield conn

    def tenant_store_connection(self):
        return self.connection(self.s.tenant_store_database)

    def close_all(self) -> None:
        with self._lock:
            for p in self._pools.values():
                p.close()
            self._pools.clear()
