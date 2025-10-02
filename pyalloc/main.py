"""Demo IP allocator worker - DEMO ONLY."""

import logging
import sqlite3
import threading
import time
from typing import Optional

from .allocator import IPPool

logger = logging.getLogger(__name__)

# Global state
_pool: Optional[IPPool] = None
_stop_event = threading.Event()
_worker_thread: Optional[threading.Thread] = None


def demo_worker(conn: sqlite3.Connection, pool: IPPool) -> None:
    """Demo worker that periodically logs pool statistics.
    
    Args:
        conn: Database connection (unused in demo)
        pool: IP pool to monitor
    """
    logger.info("Demo IP allocator worker started")
    
    while not _stop_event.is_set():
        try:
            stats = pool.get_stats()
            logger.debug(f"IP Pool stats: {stats}")
            
            # Demo: Store stats in database (optional)
            # conn.execute(
            #     "INSERT INTO system_stats (metric_name, metric_value) VALUES (?, ?)",
            #     ("ip_pool_utilization", stats["utilization_percent"])
            # )
            # conn.commit()
            
        except Exception as e:
            logger.error(f"Demo worker error: {e}")
        
        # Wait 60 seconds between stats updates
        _stop_event.wait(60)
    
    logger.info("Demo IP allocator worker stopped")


def start(conn: sqlite3.Connection, network: str = "192.168.1.0/24") -> threading.Thread:
    """Start the demo IP allocator worker.
    
    Args:
        conn: Database connection
        network: Network to manage (CIDR notation)
        
    Returns:
        Started thread
    """
    global _pool, _worker_thread
    
    if _worker_thread and _worker_thread.is_alive():
        logger.warning("Demo allocator already running")
        return _worker_thread
    
    logger.info(f"Starting demo IP allocator for network: {network}")
    
    _pool = IPPool(network)
    _stop_event.clear()
    
    _worker_thread = threading.Thread(
        target=demo_worker,
        args=(conn, _pool),
        daemon=True,
        name="DemoIPAlloc"
    )
    _worker_thread.start()
    
    return _worker_thread


def stop() -> None:
    """Stop the demo IP allocator worker."""
    global _worker_thread, _pool
    
    logger.info("Stopping demo IP allocator...")
    _stop_event.set()
    
    if _worker_thread and _worker_thread.is_alive():
        _worker_thread.join(timeout=5)
        if _worker_thread.is_alive():
            logger.warning("Demo allocator did not stop gracefully")
    
    _worker_thread = None
    _pool = None
    logger.info("Demo IP allocator stopped")


def get_pool() -> Optional[IPPool]:
    """Get the current IP pool instance (for demo/testing)."""
    return _pool