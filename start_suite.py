#!/usr/bin/env python3
"""Entry point for monitoring suite. Updated for Python 3.12."""
import asyncio
import threading
import uvicorn
from api.main import app as api_app
from shared.db import init_db
from pyhole.dns_monitor import start as dns_start
from pyalloc.main import start as alloc_start

async def run_api():
    config = uvicorn.Config(api_app, host="127.0.0.1", port=8090, log_level="info")
    server = uvicorn.Server(config)
    await server.serve()

def main():
    conn = init_db()
    dns_thread = threading.Thread(target=dns_start, args=(conn,), daemon=True)
    alloc_thread = threading.Thread(target=alloc_start, args=(conn,), daemon=True)
    dns_thread.start()
    alloc_thread.start()
    
    try:
        asyncio.run(run_api())
    except KeyboardInterrupt:
        print("Shutting down...")

if __name__ == "__main__":
    main()
