from pathlib import Path
import os
import logging

# Basic shared configuration used across the suite
INTERFACE = os.getenv("SUITE_INTERFACE", "eth0")
DNS_PORT = int(os.getenv("SUITE_DNS_PORT", "5335"))
LOG_LEVEL = os.getenv("SUITE_LOG_LEVEL", "INFO")
DATA_DIR = Path(os.getenv("SUITE_DATA_DIR", "data"))

DATA_DIR.mkdir(parents=True, exist_ok=True)

DB_PATH = DATA_DIR / "shared.sqlite"

logging.basicConfig(level=LOG_LEVEL,
                    format="%(asctime)s [%(levelname)s] %(message)s")
