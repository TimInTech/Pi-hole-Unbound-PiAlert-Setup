import ipaddress
import logging
import threading
import time
from typing import List

logger = logging.getLogger(__name__)

class IPPool:
    def __init__(self, network: str):
        self.network = ipaddress.ip_network(network)
        self.lock = threading.Lock()
        self.allocated = set()

    def allocate(self) -> str:
        with self.lock:
            for ip in self.network.hosts():
                ip_str = str(ip)
                if ip_str not in self.allocated:
                    self.allocated.add(ip_str)
                    logger.info("Allocated IP %s", ip_str)
                    return ip_str
            raise RuntimeError("No free IP addresses")

    def release(self, ip: str) -> None:
        with self.lock:
            self.allocated.discard(ip)
            logger.info("Released IP %s", ip)
