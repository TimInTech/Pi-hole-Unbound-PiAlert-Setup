<<<<<<< HEAD
"""Shared configuration for the Pi-hole suite."""

=======
"""Shared configuration helpers for the suite."""
>>>>>>> origin/main
import logging
import os
from pathlib import Path

<<<<<<< HEAD
# Configuration from environment
INTERFACE = os.getenv("SUITE_INTERFACE", "eth0")
API_HOST = os.getenv("SUITE_HOST", "127.0.0.1")
API_PORT = int(os.getenv("SUITE_PORT", "8090"))
LOG_LEVEL = os.getenv("SUITE_LOG_LEVEL", "INFO")
DATA_DIR = Path(os.getenv("SUITE_DATA_DIR", "data"))
PIHOLE_LOG_PATH = Path(os.getenv("PIHOLE_LOG_PATH", "/var/log/pihole.log"))

# Ensure data directory exists
DATA_DIR.mkdir(parents=True, exist_ok=True)

# Database path
DB_PATH = DATA_DIR / "shared.sqlite"

# Logging configuration
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL.upper()),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)

# Module logger
logger = logging.getLogger(__name__)
logger.info(f"Configuration loaded - Data directory: {DATA_DIR}, Log level: {LOG_LEVEL}")
=======
INTERFACE = os.getenv("SUITE_INTERFACE", "eth0")
DNS_PORT = int(os.getenv("SUITE_DNS_PORT", "5335"))
LOG_LEVEL = os.getenv("SUITE_LOG_LEVEL", "INFO")
DATA_DIR = Path(os.getenv("SUITE_DATA_DIR", "data"))

DATA_DIR.mkdir(parents=True, exist_ok=True)

DB_PATH = DATA_DIR / "shared.sqlite"

logging.basicConfig(level=LOG_LEVEL, format="%(asctime)s [%(levelname)s] %(message)s")
>>>>>>> origin/main
