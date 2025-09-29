"""Simple Pi-hole log tailer."""
import logging
import threading
import time
from pathlib import Path
from typing import Optional, Tuple

logger = logging.getLogger(__name__)

PIHOLE_LOG = Path("/var/log/pihole.log")
_stop_event = threading.Event()


def parse_line(line: str) -> Optional[Tuple[str, str, str, str]]:
    parts = line.strip().split()
    if len(parts) < 5:
        return None
    timestamp = " ".join(parts[:2])
    action = parts[2]
    client = parts[3].rstrip(":")
    query = parts[4]
    return timestamp, client, query, action


def monitor(conn, log_path: Optional[Path] = None) -> None:
    log_path = log_path or PIHOLE_LOG
    logger.info("Starting DNS monitor on %s", log_path)
    last_pos = 0
    while not _stop_event.is_set():
        if log_path.exists():
            with log_path.open() as handle:
                handle.seek(last_pos)
                for line in handle:
                    parsed = parse_line(line)
                    if parsed:
                        conn.execute(
                            "INSERT INTO dns_logs(timestamp, client, query, action) VALUES(?,?,?,?)",
                            parsed,
                        )
                        conn.commit()
                last_pos = handle.tell()
        time.sleep(5)


def start(conn):
    _stop_event.clear()
    thread = threading.Thread(target=monitor, args=(conn,), daemon=True)
    thread.start()
    return thread


def stop() -> None:
    _stop_event.set()
