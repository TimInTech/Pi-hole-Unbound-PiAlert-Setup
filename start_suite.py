#!/usr/bin/env python3
"""Entry point for the Pi-hole monitoring suite."""

import asyncio
import logging
import os
import threading
import sys

import uvicorn

# Setup logging
logging.basicConfig(
    level=os.getenv("SUITE_LOG_LEVEL", "INFO"),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger(__name__)

# Import application components
try:
    from api.main import app as api_app
    from pyhole.dns_monitor import start as dns_start
    from shared.db import init_db
except ImportError as e:
    logger.error(f"Failed to import required modules: {e}")
    logger.error("Make sure you've installed dependencies: pip install -r requirements.txt")
    sys.exit(1)

# Optional demo component - disabled by default
ENABLE_PYALLOC_DEMO = os.getenv("ENABLE_PYALLOC_DEMO", "false").lower() == "true"
if ENABLE_PYALLOC_DEMO:
    try:
        from pyalloc.main import start as alloc_start
        logger.info("PyAlloc demo component enabled")
    except ImportError:
        logger.warning("PyAlloc demo component not available")
        ENABLE_PYALLOC_DEMO = False


async def run_api() -> None:
    """Run the FastAPI application."""
    port = int(os.getenv("SUITE_PORT", "8090"))
    host = os.getenv("SUITE_HOST", "127.0.0.1")

    config = uvicorn.Config(api_app, host=host, port=port, log_level="info", access_log=True)
    server = uvicorn.Server(config)
    await server.serve()


def main() -> None:
    """Main application entry point."""
    logger.info("Starting Pi-hole Suite...")

    # Verify API key
    api_key = os.environ.get("SUITE_API_KEY")
    if not api_key:
        logger.error("SUITE_API_KEY environment variable must be set")
        logger.info("Generate one with: openssl rand -hex 16")
        sys.exit(1)

    # Initialize database
    try:
        conn = init_db()
        logger.info("Database initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize database: {e}")
        sys.exit(1)

    # Start core DNS monitoring
    try:
        dns_thread = threading.Thread(
            target=dns_start,
            args=(conn,),
            daemon=True,
            name="DNSMonitor",
        )
        dns_thread.start()
        logger.info("DNS monitor started")
    except Exception as e:
        logger.error(f"Failed to start DNS monitor: {e}")

    # Start optional demo allocator if enabled
    if ENABLE_PYALLOC_DEMO:
        try:
            alloc_thread = threading.Thread(
                target=alloc_start,
                args=(conn,),
                daemon=True,
                name="AllocDemo",
            )
            alloc_thread.start()
            logger.info("PyAlloc demo component started")
        except Exception as e:
            logger.warning(f"Failed to start PyAlloc demo: {e}")

    logger.info(f"API Key: {api_key[:8]}...")
    logger.info("Starting API server...")

    try:
        asyncio.run(run_api())
    except KeyboardInterrupt:
        logger.info("Shutting down...")
    except Exception as e:
        logger.error(f"Application error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
