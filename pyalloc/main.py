import threading
import time
import logging
from .allocator import IPPool
from shared import db

logger = logging.getLogger(__name__)

_pool = None
_stop_event = threading.Event()

def start(conn, network: str = "192.168.0.0/24"):
    global _pool
    _pool = IPPool(network)
    logger.info("Starting IP allocator on %s", network)
    # This stub does not dynamically assign leases; in a real system,
    # DHCP hooks would update the database.
    thread = threading.Thread(target=_run, args=(conn,), daemon=True)
    thread.start()
    return thread


def _run(conn):
    while not _stop_event.is_set():
        time.sleep(60)


def stop():
    _stop_event.set()
