"""Simple IP pool allocator - DEMO ONLY."""

import ipaddress
import logging
import threading
from typing import Set

logger = logging.getLogger(__name__)


class IPPool:
    """Simple IP address pool manager (Demo implementation)."""
    
    def __init__(self, network: str = "192.168.1.0/24"):
        """Initialize IP pool with network range.
        
        Args:
            network: CIDR network notation (e.g., "192.168.1.0/24")
        """
        self.network = ipaddress.ip_network(network)
        self.allocated: Set[str] = set()
        self.lock = threading.Lock()
        logger.info(f"Initialized IP pool for network: {network}")
    
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
                    logger.info(f"Allocated IP: {ip_str}")
                    return ip_str
            
            raise RuntimeError(f"No free IP addresses in {self.network}")
    
    def release(self, ip: str) -> bool:
        """Release an allocated IP address.
        
        Args:
            ip: IP address to release
            
        Returns:
            True if released, False if not allocated
        """
        with self.lock:
            if ip in self.allocated:
                self.allocated.remove(ip)
                logger.info(f"Released IP: {ip}")
                return True
            return False
    
    def is_allocated(self, ip: str) -> bool:
        """Check if IP is allocated.
        
        Args:
            ip: IP address to check
            
        Returns:
            True if allocated
        """
        with self.lock:
            return ip in self.allocated
    
    def get_stats(self) -> dict:
        """Get allocation statistics.
        
        Returns:
            Dictionary with pool statistics
        """
        with self.lock:
            total_hosts = self.network.num_addresses - 2  # Exclude network and broadcast
            allocated_count = len(self.allocated)
            return {
                "network": str(self.network),
                "total_hosts": total_hosts,
                "allocated": allocated_count,
                "available": total_hosts - allocated_count,
                "utilization_percent": (allocated_count / total_hosts) * 100 if total_hosts > 0 else 0
            }