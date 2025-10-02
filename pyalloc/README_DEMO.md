# PyAlloc - Demo IP Allocator

⚠️ **This is a DEMO component only** ⚠️

This directory contains a simple IP address allocator that serves as a proof-of-concept. It is **disabled by default** and not required for the main Pi-hole + Unbound + NetAlertX installation.

## Purpose

- Demonstrates how additional network management tools could be integrated
- Shows threading patterns for background workers
- Provides a basic IP pool management system

## Usage

The pyalloc component is **disabled by default**. To enable it for testing:

```bash
# Enable in environment
export ENABLE_PYALLOC_DEMO=true

# Or add to .env file
echo "ENABLE_PYALLOC_DEMO=true" >> .env
```

## Production Use

For production environments, consider using proper DHCP management tools:
- ISC DHCP Server
- Dnsmasq (built into Pi-hole)
- Network management systems
- Router/firewall DHCP services

This demo allocator is **not suitable for production use**.