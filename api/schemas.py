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