# AGENTS.md — Instructions for Codex (CLI)

This repository is a Bash-based installer and helper toolkit for Pi-hole v6 + Unbound (and optional components).
Codex should work **autonomously**: read files first, then execute changes in small reviewable steps.
**Never log secrets.**

## 0) Start Here (mandatory)
1) Read `AGENTS.md` and `report.md` first.
2) Run an **audit only** pass (no edits): identify duplicated UI/logging code, ANSI usage, and fragile bash patterns.
3) Only then refactor using the existing new files:
   - `scripts/lib/ui.sh`
   - `scripts/nightly_test.sh`
   - existing local modifications in `install.sh`
   - `CODEX_PROMPT.md` (if present)
Do **not** discard or revert these.

## 1) Mission
- Make menu flow, console UI, and logs look/behave consistently across all scripts.
- Improve reliability: idempotency/resume safety, robust error handling, reality checks.
- Provide a long-running (“overnight”) test runner to uncover regressions without interactive prompts.

## 2) Hard constraints (do not violate)
- **No new user-facing features** (no new menus/pages/flows). Only unify/harden existing behavior.
- **Centralize styling**: no scattered raw ANSI codes; no ad-hoc colors. All UI formatting comes from `scripts/lib/ui.sh`.
- **No secrets in logs**: never print API keys/tokens; never echo `.env` files; never `cat` env files in logs.
- Keep changes minimal and focused. Avoid renames/moves unless required for a real bug fix.
- Prefer portable POSIX-ish patterns where feasible, but Bash is expected.
- **Pi-hole v6 only**: do not (re-)introduce legacy v5 commands or assumptions.


## Precedence / Konfliktauflösung (wichtig)
Wenn sich Anweisungen widersprechen, gilt diese Reihenfolge:
1) `AGENTS.md` (höchste Priorität)
2) `CODEX_PROMPT.md`
3) `report.md` (nur Kontext/Historie, nicht bindend)

## 3) Sources of truth / regressions
Use the Debian test log as regression reference:
- Local file (preferred): `debiantestinsall.txt` (if present in repo)
- Reference link (secondary): http://192.168.178.200:8085/gummi/Pi-hole-Unbound-PiAlert-Setup/src/branch/main/debiantestinsall.txt

Key historical regressions:
- Pi-hole v6 “Not Ready” when upstreams are empty (must ensure upstreams configured in `pihole.toml`).
- DNS breakage if resolver is switched too early.
- NetAlertX container restart loop due to `/data` permissions (now opt-in; do not force-fix by default).
- Python suite systemd hardening/path problems (`203/EXEC`, `200/CHDIR`) and stale state flags.

## 4) Repo map (high-value files)
- `install.sh` — main installer (idempotent with state file)
- `scripts/console_menu.sh` — console menu UI
- `scripts/post_install_check.sh` — post install checks
- `scripts/repo_selftest.sh` — quick repo checks
- `tools/pihole_maintenance_pro.sh` — maintenance helper
- `start_suite.py` — optional local API suite
- `scripts/lib/ui.sh` — central UI/logging library (new; must be used)
- `scripts/nightly_test.sh` — long runner (new; must be expanded, not replaced)

## 5) Required UI/UX consistency

### 5.1 Centralize UI + logging (mandatory)
All scripts must source `scripts/lib/ui.sh` and use its functions:
- TTY detection, `NO_COLOR` support, safe reset
- Kanonische Log-Funktionen sind: `log_info`, `log_ok`, `log_warn`, `log_err`
- section/header helpers
- prompt helpers (confirm/select) used by menu scripts

Rules:
- No scattered ANSI escapes (`\033[` etc.) in scripts.
- No `echo -e`. Use `printf`.
- Output must remain readable when colors are disabled.

### 5.2 Standard log format
- Consistent prefixes: `INFO`, `OK`, `WARN`, `ERR` (or repo’s established equivalent).
- Timestamping: if already used in `install.sh`, don’t introduce a competing style.
- Errors must include: what failed + minimal hint; exit non-zero when appropriate.

## 6) Engineering rules for Bash
Prefer:
- `printf '%s\n' ...`
- strict quoting: `"$var"`
- `mktemp` for temp files
- `SCRIPT_DIR` via `${BASH_SOURCE[0]}` (never assume CWD)
- `command -v` checks for optional tools

Avoid:
- `eval`
- unquoted vars
- parsing `ls`
- static temp file names in `/tmp`

ShellCheck:
- If installed, keep scripts ShellCheck-clean.
- If you must suppress warnings, use inline `# shellcheck disable=...` with a short justification.

## 7) Idempotency + state file rules
State file is an optimization, not truth.
- Always validate state flags against reality (services active, files exist, correct permissions).
- If state says OK but reality disagrees: reset the flag and re-run the step.
- Resume must not regress the system or repeat destructive actions.
- Use clear exit codes for hard failures.

## 8) Security requirements
- No secrets in logs.
- Secret env files must be restrictive (e.g. `0640`, root-owned, appropriate group).
- Prefer system-owned paths for systemd services; do not loosen hardening to “make it work”.
- Tests must not prompt for sudo; only use `sudo -n` in automated runners.

## 9) Testing: quick + overnight

### 9.1 Quick checks (must stay green)
- `bash -n` on all `*.sh`
- `scripts/repo_selftest.sh`

### 9.2 Overnight runner (`scripts/nightly_test.sh`)
Expand the existing runner so it:
- Runs quick checks
- Runs `shellcheck` and `shfmt` if installed (warn + continue if missing)
- Exercises installer logic safely:
  - Only if `sudo -n true` succeeds (no prompts)
  - Prefer DRY_RUN / safe modes if supported
  - Repeat `--resume` passes to catch idempotency issues
- Aggregates logs and prints a summary
- Is interruptible (Ctrl+C) and still prints a partial summary
- Uses timeouts on long operations; never runs `apt upgrade` as part of tests

## 10) Work style for Codex
- Work in small, reviewable steps (prefer multiple small commits).
- Refactor by introducing shared helpers first, then updating callers.
- Don’t rewrite everything: surgical changes are valued.
- Ask at most 1–2 questions only if blocked by ambiguity that changes user-facing behavior.

## 11) Definition of done (must satisfy)
Before finishing:
- `bash -n` passes on all `*.sh`
- `scripts/repo_selftest.sh` passes
- `scripts/nightly_test.sh` short run passes (non-interactive; respects sudo -n)
- Append a brief “Codex Änderungen” section to `report.md`:
  - what changed (files)
  - how to test
  - remaining known issues (if any)
