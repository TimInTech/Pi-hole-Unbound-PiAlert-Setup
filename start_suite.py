#!/usr/bin/env python3
"""Entry point to start the integrated monitoring suite."""
import threading
import uvicorn
from api import main as api_main
from shared import db
from pyhole import dns_monitor
from pyalloc import main as alloc_main


def run_api():
    uvicorn.run(api_main.app, host="127.0.0.1", port=8090, log_level="info")


def main():
    conn = db.init_db()
    dns_monitor.start(conn)
    alloc_main.start(conn)
    api_thread = threading.Thread(target=run_api, daemon=True)
    api_thread.start()
    try:
        while True:
            api_thread.join(1)
    except KeyboardInterrupt:
        dns_monitor.stop()
        alloc_main.stop()
        print("Shutting down")


if __name__ == "__main__":
    main()
