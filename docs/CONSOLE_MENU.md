# Console Menu User Guide

## Overview

The console menu provides an interactive interface for managing your Pi-hole + Unbound + Pi.Alert installation. It offers convenient access to verification tools, maintenance tasks, and system monitoring.

## Quick Start

### Running the Menu

```bash
./scripts/console_menu.sh
```

### With Dialog Support (Recommended)

For a better graphical menu experience, install `dialog`:

```bash
sudo apt-get install -y dialog
```

The menu will automatically use dialog if available, otherwise it falls back to a text-based interface.

## Menu Options

### [1] Post-Install Check (Quick)
- Runs a fast system health check
- No sudo required
- Checks: Unbound, Pi-hole FTL, v6 upstream configuration
- Displays PASS/WARN/FAIL summary

### [2] Post-Install Check (Full)
- Comprehensive system verification
- **Requires sudo**
- Checks all components including Docker containers
- Shows detailed configuration status
- Network and DNS settings

### [3] Show Service URLs
- Displays detected service URLs
- Pi-hole Admin interface
- NetAlertX/Pi.Alert dashboard (if running)
- No sudo required

### [4] Manual Steps Guide
- Shows step-by-step verification commands
- Expected output for each command
- Troubleshooting tips
- Viewable with `less` if available

### [5] Maintenance Pro (SAFE mode)
- **Requires sudo and confirmation**
- System maintenance tasks:
  - Package updates
  - Pi-hole component upgrades
  - Temporary file cleanup
  - Service restarts
- Creates detailed logs in `/var/log/`
- **WARNING:** Modifies system configuration

### [6] View Logs
- Access to maintenance and system logs
- Options:
  - Latest maintenance log
  - Pi-hole FTL systemd journal
  - Unbound systemd journal
- Requires sudo for some log files

### [7] Exit
- Cleanly exits the menu

## Creating a Convenient Alias

### For Bash

Add to your `~/.bash_aliases` or `~/.bashrc`:

```bash
echo "alias pihole-suite='bash ~/Pi-hole-Unbound-PiAlert-Setup/scripts/console_menu.sh'" >> ~/.bash_aliases
source ~/.bash_aliases
```

Then run with:
```bash
pihole-suite
```

### For Zsh

Add to your `~/.zshrc`:

```bash
echo "alias pihole-suite='bash ~/Pi-hole-Unbound-PiAlert-Setup/scripts/console_menu.sh'" >> ~/.zshrc
source ~/.zshrc
```

### System-Wide Alias (All Users)

Create a symlink in `/usr/local/bin` (requires sudo):

```bash
sudo ln -s ~/Pi-hole-Unbound-PiAlert-Setup/scripts/console_menu.sh /usr/local/bin/pihole-suite
```

Then any user can run:
```bash
pihole-suite
```

## Non-Interactive Mode

### Check Mode

Verify the menu can start and dependencies are available:

```bash
./scripts/console_menu.sh --check
```

Output:
```
[INFO] dialog not installed (optional, fallback to text menu available)
[PASS] post_install_check.sh found
[PASS] pihole_maintenance_pro.sh found
[INFO] Console menu available (text mode)
[PASS] Console menu check completed
```

### Help

```bash
./scripts/console_menu.sh --help
```

## Safety Notes

### Sudo Usage

Some menu options require sudo privileges:
- **Full Check** - Reads Pi-hole v6 config files
- **Maintenance Pro** - Modifies system configuration
- **View Logs** - Accesses system log files

The menu will:
1. **Always ask for confirmation** before sudo operations
2. Display what the operation will do
3. Allow you to cancel at any time

### Maintenance Pro Safety

When running Maintenance Pro:
- A **backup is created** before modifications
- Detailed logs are saved to `/var/log/pihole_maintenance_pro_*.log`
- Operations are **non-destructive** (updates, not removals)
- Services are restarted gracefully

**To cancel:** Press `Ctrl+C` or answer `N` to confirmation prompts.

## Troubleshooting

### Menu Doesn't Start

Check script permissions:
```bash
chmod +x scripts/console_menu.sh
```

Verify syntax:
```bash
bash -n scripts/console_menu.sh
```

### Dialog Not Working

Install dialog package:
```bash
sudo apt-get update
sudo apt-get install -y dialog
```

Or use the text fallback (works without dialog).

### "Permission Denied" Errors

Some operations require sudo. The menu will prompt when needed.

To run the entire menu with sudo (not recommended):
```bash
sudo ./scripts/console_menu.sh
```

**Better:** Run menu normally and provide sudo password when prompted.

## Advanced Usage

### Scripted Execution

While the menu is interactive, individual tools can be run non-interactively:

```bash
# Quick check
./scripts/post_install_check.sh --quick

# Full check
sudo ./scripts/post_install_check.sh --full

# Show URLs only
./scripts/post_install_check.sh --urls

# View manual steps
./scripts/post_install_check.sh --steps | less
```

### Integration with Cron

For automated checks (read-only):

```bash
# Add to crontab
0 */6 * * * /home/user/Pi-hole-Unbound-PiAlert-Setup/scripts/post_install_check.sh --quick >> /var/log/pihole_check.log 2>&1
```

**Do NOT** run Maintenance Pro via cron without careful consideration.

## File Locations

- Menu script: `scripts/console_menu.sh`
- Post-install checker: `scripts/post_install_check.sh`
- Maintenance tool: `tools/pihole_maintenance_pro.sh`
- Logs: `/var/log/pihole_maintenance_pro_*.log`

## Support

For issues or questions:
- Check `scripts/post_install_check.sh --steps` for manual verification
- Review logs in `/var/log/`
- Consult main README.md for troubleshooting

## License

Same as main project (MIT License)
