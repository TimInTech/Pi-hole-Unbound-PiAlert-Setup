# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Authenticated read-only DNS dashboard at `/dashboard/` alongside the separate maintenance panel at `/`.
- Production setup and API data-availability notes in both READMEs.
- **Rescue & Backup Menu** (`scripts/rescue_menu.sh` v1.0.0) — standalone interactive recovery tool with:
  - System status check (services, DNS, ports, temperature)
  - DNS loop / upstream check with blocking test
  - Nightly diagnostic integration
  - Backup & restore (pihole.toml, Unbound config, systemd drop-ins)
  - Last-Known-Good restore
  - Emergency DNS bypass (sets Pi directly to 8.8.8.8/1.1.1.1, fully reversible)
  - Pi-hole → Unbound standard fix
  - Router / client DNS hint (FritzBox guide)
  - Session log at `/var/log/pihole-rescue-menu.log`
- **Global rescue command**: `/usr/local/bin/pihole-rescue` (symlink installed by rescue setup)
- **Console menu** (`scripts/console_menu.sh`): new option [7] Rescue & Backup Menu links to `pihole-rescue`
- **Unified output format**: `tools/pihole_maintenance_pro.sh` `run_step()` now uses `log_ok`/`log_warn`/`log_err` from `scripts/lib/ui.sh`

### Changed
- Existing deployments with the maintenance panel can use `--upgrade-only` without changing DNS configuration or the Python environment.
- README platform, Python, dashboard, maintenance, and repository-structure details now match the current implementation.
- Console menu Exit moved from [7] to [8] to accommodate new Rescue entry
- `action_check_mode()` in console menu now also validates rescue_menu availability

### Fixed
- Read Pi-hole's configured DNS upstream through the suite service's existing read-only `pihole` group access, avoiding a `sudo` call that failed under systemd hardening.
- Removed the now-unneeded upstream-helper sudoers permission.

### Security
- Bound DNS-log line parsing and keep the browser API key in memory only.
- Grant the suite service read access to Pi-hole logs through its supplementary group.
- Restrict the test workflow token to `contents: read`.
- Removed outdated screenshots that showed failed checks or the private LAN address.

## [0.2.0] — 2026-01-02

### Added
- Post-install verification tool: `scripts/post_install_check.sh`
  (`--quick`, `--full`, `--urls`, `--steps` modes)
- Interactive console menu: `scripts/console_menu.sh`
  (dialog UI if available, text fallback; `--check` mode)
- Repository self-test: `scripts/repo_selftest.sh`
  (syntax checks, permissions, basic sanity)
- Maintenance tool: `tools/pihole_maintenance_pro.sh`
  (optional, invoked via console menu with confirmation)
- Shared UI library: `scripts/lib/ui.sh`
  (colors, log helpers, confirm/pause — used by all scripts)
- Nightly test runner: `scripts/nightly_test.sh`

### Changed
- Installer persists Pi-hole v6 DNS upstream via `/etc/pihole/pihole.toml`
- Documentation expanded with manual verification steps and console menu usage

### Fixed
- Removed non-portable whitespace regex usage in sed (use POSIX `[[:space:]]`)

## [0.1.0] — 2025-01-01

- Initial repository: installer, basic docs, setup flow for Pi-hole + Unbound
