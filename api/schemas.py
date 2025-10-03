"""Pydantic schemas for API responses."""

from typing import Optional

from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    """Health check response."""
    ok: bool = Field(..., description="Whether the service is healthy")
    message: Optional[str] = Field(None, description="Optional status message")
    version: Optional[str] = Field(None, description="API version")


class DNSLogResponse(BaseModel):
    """DNS log entry response."""
    timestamp: str = Field(..., description="Query timestamp")
    client: str = Field(..., description="Client IP address")
    query: str = Field(..., description="DNS query domain")
    action: str = Field(..., description="Query action (query, blocked, etc.)")


class LeaseResponse(BaseModel):
    """DHCP lease response."""
    ip: str = Field(..., description="IP address")
    mac: str = Field(..., description="MAC address")
    hostname: Optional[str] = Field(None, description="Device hostname")
    lease_start: Optional[str] = Field(None, description="Lease start time")
    lease_end: Optional[str] = Field(None, description="Lease end time")


class DeviceResponse(BaseModel):
    """Network device response."""
    id: int = Field(..., description="Device ID")
    ip: str = Field(..., description="IP address")
    mac: str = Field(..., description="MAC address")
    hostname: Optional[str] = Field(None, description="Device hostname")
    last_seen: Optional[str] = Field(None, description="Last seen timestamp")


class StatsResponse(BaseModel):
    """System statistics response."""
    total_dns_logs: int = Field(..., description="Total DNS log entries")
    total_devices: int = Field(..., description="Total known devices")
    recent_queries: int = Field(..., description="Queries in the last hour")
"""Pydantic models for API request/response validation."""
from typing import Optional
from pydantic import BaseModel, Field, field_validator
import ipaddress


class DeviceRequest(BaseModel):
    """Request model for device operations."""
    ip_address: str = Field(..., description="IP address of the device")
    status: bool = Field(..., description="Device status (active/inactive)")
    hostname: Optional[str] = Field(None, description="Device hostname")
    mac_address: Optional[str] = Field(None, description="MAC address")
    
    @field_validator('ip_address')
    @classmethod
    def validate_ip_address(cls, v):
        """Validate IP address format."""
        try:
            ipaddress.ip_address(v)
        except ValueError:
            raise ValueError('Invalid IP address format')
        return v
    
    @field_validator('mac_address')
    @classmethod
    def validate_mac_address(cls, v):
        """Validate MAC address format if provided."""
        if v is None:
            return v
        # Simple MAC address validation (XX:XX:XX:XX:XX:XX format)
        if not (len(v) == 17 and v.count(':') == 5):
            raise ValueError('Invalid MAC address format')
        return v.lower()


class DeviceResponse(BaseModel):
    """Response model for device data."""
    id: Optional[int] = None
    ip: str
    mac: Optional[str] = None
    hostname: Optional[str] = None
    last_seen: Optional[str] = None


class DNSLogResponse(BaseModel):
    """Response model for DNS log entries."""
    timestamp: str
    client: str
    query: str
    action: str


class HealthResponse(BaseModel):
    """Response model for health check."""
    ok: bool
