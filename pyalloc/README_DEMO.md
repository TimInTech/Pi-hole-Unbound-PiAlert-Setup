# PyAlloc - Demo IP Allocator

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