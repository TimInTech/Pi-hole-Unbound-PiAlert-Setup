"""Placeholder IP allocator worker."""
import logging
import threading
import time

from .allocator import IPPool

logger = logging.getLogger(__name__)

_pool = None
_stop_event = threading.Event()


def start(conn, network: str = "192.168.0.0/24"):
    del conn  # not used yet
    global _pool
    _pool = IPPool(network)
    logger.info("Starting IP allocator for %s", network)
    _stop_event.clear()
    thread = threading.Thread(target=_run, daemon=True)
    thread.start()
    return thread


def _run() -> None:
    while not _stop_event.is_set():
        time.sleep(60)


def stop() -> None:
    _stop_event.set()
