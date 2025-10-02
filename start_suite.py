#!/usr/bin/env python3
"""Entry point for the Pi-hole monitoring suite."""
import asyncio
import os
import threading

import uvicorn

from api.main import app as api_app
from pyhole.dns_monitor import start as dns_start
from shared.db import init_db

# Optional demo component - disabled by default for one-click installer
ENABLE_PYALLOC_DEMO = os.getenv("ENABLE_PYALLOC_DEMO", "false").lower() == "true"

if ENABLE_PYALLOC_DEMO:
    from pyalloc.main import start as alloc_start


async def run_api() -> None:
    config = uvicorn.Config(api_app, host="127.0.0.1", port=8090, log_level="info")
    server = uvicorn.Server(config)
    await server.serve()


def main() -> None:

    conn = init_db()
    
    # Start core DNS monitoring
    threading.Thread(target=dns_start, args=(conn,), daemon=True).start()
    
    # Start optional demo allocator if enabled
    if ENABLE_PYALLOC_DEMO:
        threading.Thread(target=alloc_start, args=(conn,), daemon=True).start()
        print("✓ Started with pyalloc demo component")
    else:
        print("✓ Started in production mode (pyalloc demo disabled)")
    
    try:
        asyncio.run(run_api())
    except KeyboardInterrupt:
        print("Shutting down…")


if __name__ == "__main__":
    main()
