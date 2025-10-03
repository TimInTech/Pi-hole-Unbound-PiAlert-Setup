from __future__ import annotations
import ipaddress
import threading
import logging

logger = logging.getLogger(__name__)

class IPPool:
    """Simple in-memory IP allocator for demonstration purposes."""
    def __init__(self, network: str = "192.168.1.0/24") -> None:
        self.network = ipaddress.ip_network(network, strict=False)
        self.lock = threading.Lock()
        self.allocated: set[str] = set()

    def allocate(self) -> str:
        """Allocate next available IP address.

        Returns:
            String IP address

        Raises:
            RuntimeError: If no IPs available
        """
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
            if ip in self.allocated:
                self.allocated.remove(ip)
                logger.info("Released IP %s", ip)
