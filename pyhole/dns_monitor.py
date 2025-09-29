import threading
import time
import logging
from pathlib import Path
from typing import Optional, Tuple

from shared import db

PIHOLE_LOG = Path('/var/log/pihole.log')

logger = logging.getLogger(__name__)

_stop_event = threading.Event()

def parse_line(line: str) -> Optional[Tuple[str, str, str, str]]:
    parts = line.strip().split()
    if len(parts) < 5:
        return None
    timestamp = " ".join(parts[:2])
    action = parts[2]
    client = parts[3].rstrip(':')
    query = parts[4]
    return timestamp, client, query, action

def monitor(conn, log_path: Optional[Path] = None):
    log_path = log_path or PIHOLE_LOG
    logger.info("Starting DNS monitor on %s", log_path)
    last_pos = 0
    while not _stop_event.is_set():
        if log_path.exists():
            with log_path.open() as fh:
                fh.seek(last_pos)
                for line in fh:
                    parsed = parse_line(line)
                    if parsed:
                        cur = conn.cursor()
                        cur.execute(
                            "INSERT OR IGNORE INTO dns_logs(timestamp, client, query, action) VALUES(?,?,?,?)",
                            parsed,
                        )
                        conn.commit()
                last_pos = fh.tell()
        time.sleep(5)

def start(conn):
    thread = threading.Thread(target=monitor, args=(conn,), daemon=True)
    thread.start()
    return thread

def stop():
    _stop_event.set()
