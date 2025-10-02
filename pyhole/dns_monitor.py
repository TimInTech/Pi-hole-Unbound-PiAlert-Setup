"""Simple Pi-hole log tailer with log rotation support."""
import logging
import os
import threading
import time
from pathlib import Path
from typing import Optional, Tuple

logger = logging.getLogger(__name__)

PIHOLE_LOG = Path("/var/log/pihole.log")
_stop_event = threading.Event()


def parse_line(line: str) -> Optional[Tuple[str, str, str, str]]:
    """Parse a Pi-hole log line into components."""
    parts = line.strip().split()
    if len(parts) < 5:
        return None
    timestamp = " ".join(parts[:2])
    action = parts[2]
    client = parts[3].rstrip(":")
    query = parts[4]
    return timestamp, client, query, action


def monitor(conn, log_path: Optional[Path] = None) -> None:
    """Monitor Pi-hole log file with log rotation support."""
    log_path = log_path or PIHOLE_LOG
    logger.info("Starting DNS monitor on %s", log_path)
    
    last_pos = 0
    last_inode = None
    
    while not _stop_event.is_set():
        try:
            if log_path.exists():
                # Check if log file was rotated (inode changed)
                current_stat = log_path.stat()
                current_inode = current_stat.st_ino
                
                if last_inode is not None and current_inode != last_inode:
                    logger.info("Log rotation detected, resetting position")
                    last_pos = 0
                
                last_inode = current_inode
                
                # Check if file was truncated
                if current_stat.st_size < last_pos:
                    logger.info("Log file truncated, resetting position")
                    last_pos = 0
                
                with log_path.open() as handle:
                    handle.seek(last_pos)
                    lines_processed = 0
                    
                    for line in handle:
                        parsed = parse_line(line)
                        if parsed:
                            try:
                                conn.execute(
                                    "INSERT INTO dns_logs(timestamp, client, query, action) VALUES(?,?,?,?)",
                                    parsed,
                                )
                                lines_processed += 1
                            except Exception as e:
                                logger.warning("Failed to insert DNS log entry: %s", e)
                    
                    if lines_processed > 0:
                        conn.commit()
                        logger.debug("Processed %d DNS log entries", lines_processed)
                    
                    last_pos = handle.tell()
            else:
                logger.warning("Pi-hole log file not found: %s", log_path)
                
        except Exception as e:
            logger.error("Error monitoring DNS log: %s", e)
        
        time.sleep(5)


def start(conn):
    """Start the DNS monitor in a background thread."""
    _stop_event.clear()
    thread = threading.Thread(target=monitor, args=(conn,), daemon=True)
    thread.start()
    return thread


def stop() -> None:
    """Stop the DNS monitor."""
    _stop_event.set()
