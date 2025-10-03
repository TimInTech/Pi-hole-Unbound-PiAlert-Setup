from __future__ import annotations
    """Simple in-memory IP allocator for demonstration purposes."""
    def __init__(self, network: str = "192.168.1.0/24") -> None:
        self.network = ipaddress.ip_network(network, strict=False)
        self.allocated: set[str] = set()



