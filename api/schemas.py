"""Pydantic models for API request/response validation."""

import ipaddress
from typing import Optional

from pydantic import BaseModel, Field, field_validator


class HealthResponse(BaseModel):
    ok: bool = Field(..., description="Whether the service is healthy")
    message: Optional[str] = Field(None, description="Optional status message")
    version: Optional[str] = Field(None, description="API version")


class DNSLogResponse(BaseModel):
    timestamp: str = Field(..., description="Query timestamp")
    client: str = Field(..., description="Client IP address")
    query: str = Field(..., description="DNS query domain")
    action: str = Field(..., description="Query action (query, blocked, etc.)")


class LeaseResponse(BaseModel):
    ip: str = Field(..., description="IP address")
    mac: str = Field(..., description="MAC address")
    hostname: Optional[str] = Field(None, description="Device hostname")
    lease_start: Optional[str] = Field(None, description="Lease start time")
    lease_end: Optional[str] = Field(None, description="Lease end time")


class DeviceResponse(BaseModel):
    id: int = Field(..., description="Device ID")
    ip: str = Field(..., description="IP address")
    mac: str = Field(..., description="MAC address")
    hostname: Optional[str] = Field(None, description="Device hostname")
    last_seen: Optional[str] = Field(None, description="Last seen timestamp")


class StatsResponse(BaseModel):
    total_dns_logs: int = Field(..., description="Total DNS log entries")
    total_devices: int = Field(..., description="Total known devices")
    recent_queries: int = Field(..., description="Queries in the last hour")


class DeviceRequest(BaseModel):
    """Request model for device operations with validation."""
    ip_address: str = Field(..., description="IP address of the device")
    status: bool = Field(..., description="Device status (active/inactive)")
    hostname: Optional[str] = Field(None, description="Device hostname")
    mac_address: Optional[str] = Field(None, description="MAC address")

    @field_validator("ip_address")
    @classmethod
    def validate_ip_address(cls, v: str) -> str:
        try:
            ipaddress.ip_address(v)
        except ValueError as exc:  # noqa: TRY003 - re-raise as ValueError for pydantic
            raise ValueError("Invalid IP address format") from exc
        return v

    @field_validator("mac_address")
    @classmethod
    def validate_mac_address(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        # Simple MAC address validation (XX:XX:XX:XX:XX:XX)
        if not (len(v) == 17 and v.count(":") == 5):
            raise ValueError("Invalid MAC address format")
        return v.lower()
