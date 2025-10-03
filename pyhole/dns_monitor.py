"""Robust Pi-hole log monitor with log rotation support."""

import logging
import re
import sqlite3
"""Simple Pi-hole log tailer with log rotation support."""
import logging
import threading
import time
from pathlib import Path
from typing import Optional, Tuple

from shared.shared_config import PIHOLE_LOG_PATH

logger = logging.getLogger(__name__)

# Global control variables
_stop_event = threading.Event()
_monitor_thread: Optional[threading.Thread] = None

# Pi-hole log regex patterns
DNS_QUERY_PATTERN = re.compile(
    r'(\w+\s+\d+\s+\d+:\d+:\d+)\s+\w+\s+(\w+)\[?\d*\]?:\s+(\S+)\s+(\S+)'
)


def parse_pihole_line(line: str) -> Optional[Tuple[str, str, str, str]]:
    """Parse a Pi-hole log line into components.
    
    Args:
        line: Raw log line from Pi-hole
        
    Returns:
        Tuple of (timestamp, action, client, query) or None if not parseable
    """
    line = line.strip()
    if not line:
        return None
        
    # Try different Pi-hole log formats
    # Format 1: Standard query
    if 'query[' in line or 'reply' in line:
        parts = line.split()
        if len(parts) >= 5:
            timestamp = ' '.join(parts[:3])  # Mon DD HH:MM:SS
            action = 'query' if 'query' in line else 'reply'
            
            # Extract client IP and domain
            for part in parts:
                if part.count('.') == 3:  # Likely an IP
                    client = part.rstrip(':')
                    break
            else:
                client = 'unknown'
                
            # Extract domain from query or reply
            for part in parts:
                if '.' in part and not part.count('.') == 3:  # Domain-like
                    query = part
                    break
            else:
                query = 'unknown'
                
            return timestamp, client, query, action
    
    # Format 2: Simplified parsing for other log types
    match = DNS_QUERY_PATTERN.search(line)
    if match:
        timestamp, action, client, query = match.groups()
        return timestamp, client, query, action
        
    return None


def monitor_pihole_log(conn: sqlite3.Connection, log_path: Path = PIHOLE_LOG_PATH) -> None:
    """Monitor Pi-hole log file with robust rotation handling.
    
    Args:
        conn: Database connection
        log_path: Path to Pi-hole log file
    """
    logger.info(f"Starting Pi-hole log monitor on {log_path}")
    
    last_pos = 0
    last_inode = None
    last_size = 0
    consecutive_errors = 0
    
    while not _stop_event.is_set():
        try:
            if not log_path.exists():
                if consecutive_errors == 0:  # Log once
                    logger.warning(f"Pi-hole log not found: {log_path}")
                consecutive_errors += 1
                time.sleep(10)
                continue
            
            # Reset error counter
            consecutive_errors = 0
            
            # Get file stats
            stat = log_path.stat()
            current_inode = stat.st_ino
            current_size = stat.st_size
            
            # Check for log rotation (inode changed)
            if last_inode is not None and current_inode != last_inode:
                logger.info("Log rotation detected (inode changed)")
                last_pos = 0
                last_size = 0
            
            # Check for truncation (size decreased)
            elif current_size < last_size:
                logger.info("Log truncation detected")
                last_pos = 0
            
            # Check if position is beyond file size
            elif last_pos > current_size:
                logger.info("Position beyond file size, resetting")
                last_pos = 0
            
            last_inode = current_inode
            last_size = current_size
            
            # Read new lines
            lines_processed = 0
            with log_path.open('r', encoding='utf-8', errors='ignore') as f:
                f.seek(last_pos)
                
                for line in f:
                    if _stop_event.is_set():
                        break
                        
                    parsed = parse_pihole_line(line)
                    if parsed:
                        timestamp, client, query, action = parsed
                        try:
                            conn.execute(
                                "INSERT INTO dns_logs (timestamp, client, query, action) VALUES (?, ?, ?, ?)",
                                (timestamp, client, query, action)
                            )
                            lines_processed += 1
                        except sqlite3.Error as e:
                            logger.warning(f"Database insert failed: {e}")
                
                last_pos = f.tell()
            
            # Commit in batches
            if lines_processed > 0:
                try:
                    conn.commit()
                    logger.debug(f"Processed {lines_processed} DNS log entries")
                except sqlite3.Error as e:
                    logger.error(f"Database commit failed: {e}")
                    
        except PermissionError:
            logger.warning(f"Permission denied reading {log_path}")
            time.sleep(30)
        except Exception as e:
            logger.error(f"Error monitoring Pi-hole log: {e}")
            consecutive_errors += 1
            if consecutive_errors > 10:
                logger.error("Too many consecutive errors, stopping monitor")
                break
        
        # Sleep between checks
        time.sleep(5)
    
    logger.info("Pi-hole log monitor stopped")


def start(conn: sqlite3.Connection, log_path: Optional[Path] = None) -> threading.Thread:
    """Start the Pi-hole log monitor in a background thread.
    
    Args:
        conn: Database connection
        log_path: Optional custom log path
        
    Returns:
        Started thread
    """
    global _monitor_thread
    
    if _monitor_thread and _monitor_thread.is_alive():
        logger.warning("DNS monitor already running")
        return _monitor_thread
    
    _stop_event.clear()
    _monitor_thread = threading.Thread(
        target=monitor_pihole_log,
        args=(conn, log_path or PIHOLE_LOG_PATH),
        daemon=True,
        name="PiHoleMonitor"
    )
    _monitor_thread.start()
    logger.info("Pi-hole DNS monitor started")
    return _monitor_thread


def stop() -> None:
    """Stop the Pi-hole log monitor."""
    global _monitor_thread
    
    logger.info("Stopping Pi-hole DNS monitor...")
    _stop_event.set()
    
    if _monitor_thread and _monitor_thread.is_alive():
        _monitor_thread.join(timeout=10)
        if _monitor_thread.is_alive():
            logger.warning("DNS monitor did not stop gracefully")
    
    _monitor_thread = None
    logger.info("Pi-hole DNS monitor stopped")


def is_running() -> bool:
    """Check if the monitor is currently running."""
    return _monitor_thread is not None and _monitor_thread.is_alive()
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
