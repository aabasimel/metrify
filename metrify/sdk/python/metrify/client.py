import time
import uuid
import threading
import logging
from datetime import datetime, timezone
from typing import Any
import httpx

logger = logging.getLogger("metrify")


class Metrify:
    def __init__(
        self, api_key: str, base_url: str = "https://api.metrify.dev",
        flush_interval: float = 5.0, flush_size: int = 100, timeout: float = 10.0,
    ):
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.flush_interval = flush_interval
        self.flush_size = flush_size
        self._buffer: list[dict] = []
        self._lock = threading.Lock()
        self._client = httpx.Client(
            base_url=self.base_url,
            headers={"X-Metrify-Key": self.api_key},
            timeout=timeout,
        )
        self._running = True
        self._flush_thread = threading.Thread(target=self._flush_loop, daemon=True)
        self._flush_thread.start()

    def track(
        self, event_name: str, customer_id: str, units: int = 1,
        properties: dict[str, Any] | None = None, timestamp: datetime | None = None,
        idempotency_key: str | None = None,
    ) -> None:
        event = {
            "event_name": event_name, "customer_id": customer_id, "units": units,
            "properties": properties,
            "timestamp": (timestamp or datetime.now(timezone.utc)).isoformat(),
            "idempotency_key": idempotency_key or str(uuid.uuid4()),
        }
        with self._lock:
            self._buffer.append(event)
            if len(self._buffer) >= self.flush_size:
                self._flush()

    def flush(self) -> None:
        with self._lock:
            self._flush()

    def _flush(self) -> None:
        if not self._buffer:
            return
        events = self._buffer.copy()
        self._buffer.clear()
        try:
            resp = self._client.post("/v1/events/batch", json={"events": events})
            resp.raise_for_status()
        except Exception as e:
            logger.error(f"Flush failed: {e}")
            self._buffer = events + self._buffer

    def _flush_loop(self) -> None:
        while self._running:
            time.sleep(self.flush_interval)
            with self._lock:
                self._flush()

    def shutdown(self) -> None:
        self._running = False
        self.flush()
        self._client.close()
