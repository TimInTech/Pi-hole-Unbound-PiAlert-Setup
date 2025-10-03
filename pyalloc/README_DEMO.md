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
⚠️ **This is a demonstration component only** ⚠️

This directory contains a simple IP address allocator that was created as a proof-of-concept. It is **not required** for the main Pi-hole + Unbound + NetAlertX installation.

## What it does

- Provides a simple IP pool management system
- Demonstrates how additional network tools could be integrated
- Shows threading patterns for background workers

## Usage in the suite

The pyalloc component is automatically disabled in the one-click installer. If you want to experiment with it:

1. Uncomment the relevant lines in `start_suite.py`
2. Review the code in `allocator.py` and `main.py`
3. Adapt it to your specific network management needs

## For production use

For production environments, consider using proper DHCP management tools or network management systems instead of this demo allocator.
