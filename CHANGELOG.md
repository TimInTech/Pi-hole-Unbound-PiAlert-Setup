# Changelog

All notable changes to this project will be documented in this file.

This project roughly follows the "Keep a Changelog" format and uses simple, practical entries.
No release automation is assumed.

## [Unreleased]

### Added
- Post-install verification tool: `scripts/post_install_check.sh` (read-only checks; includes `--quick`, `--full`, `--urls`, `--steps`)
- Interactive console menu: `scripts/console_menu.sh` (dialog UI if available, text fallback; includes `--check`)
- Repository self-test: `scripts/repo_selftest.sh` (syntax checks, permissions checks, basic repo sanity)
- Included maintenance tool: `tools/pihole_maintenance_pro.sh` (optional, invoked via console menu with confirmation)

### Changed
- Installer/Setup persists Pi-hole v6 DNS upstream configuration via `/etc/pihole/pihole.toml` (authoritative in v6)
- Documentation expanded with manual verification steps (Unbound ↔ Pi-hole ↔ DNS flow) and console menu usage

### Fixed
- Removed non-portable whitespace regex usage in sed where applicable (use POSIX `[[:space:]]`)

## [0.1.0]
- Initial repository state with installer, basic docs and setup flow.
