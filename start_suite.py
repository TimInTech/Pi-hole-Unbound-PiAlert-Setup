#!/usr/bin/env python3
"""Entry point for the Pi-hole monitoring suite."""
import asyncio
import os
import threading

import uvicorn

from api.main import app as api_app
from pyalloc.main import start as alloc_start
from pyhole.dns_monitor import start as dns_start
from shared.db import init_db


async def run_api() -> None:
    config = uvicorn.Config(api_app, host="127.0.0.1", port=8090, log_level="info")
    server = uvicorn.Server(config)
    await server.serve()


def main() -> None:
    if not os.environ.get("SUITE_API_KEY"):
        raise ValueError("SUITE_API_KEY environment variable must be set")
    conn = init_db()
    threading.Thread(target=dns_start, args=(conn,), daemon=True).start()
    threading.Thread(target=alloc_start, args=(conn,), daemon=True).start()
    try:
        asyncio.run(run_api())
    except KeyboardInterrupt:
        print("Shutting down…")


if __name__ == "__main__":
    main()
