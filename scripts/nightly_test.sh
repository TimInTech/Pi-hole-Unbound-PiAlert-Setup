#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${ROOT_DIR}/data/nightly"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="${LOG_DIR}/${RUN_ID}"

mkdir -p "$RUN_DIR"

UI_LIB="${ROOT_DIR}/scripts/lib/ui.sh"
if [[ -f "$UI_LIB" ]]; then
  # shellcheck source=/dev/null
  source "$UI_LIB"
  ui_init
fi

PASS=0
WARN=0
FAIL=0

UI_LOG_FILE="${RUN_DIR}/nightly.log"

ok() { PASS=$((PASS+1)); log_ok "$*"; }
warn() { WARN=$((WARN+1)); log_warn "$*"; }
fail() { FAIL=$((FAIL+1)); log_err "$*"; }

run_with_timeout() {
  local timeout_s="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$timeout_s" "$@"
  else
    "$@"
  fi
}

summary() {
  log_info "--- SUMMARY ---"
  log_info "PASS=$PASS WARN=$WARN FAIL=$FAIL"
  log_info "Logs: $RUN_DIR"
  if [[ $FAIL -ne 0 ]]; then
    return 1
  fi
  return 0
}

on_int() {
  warn "Interrupted (Ctrl+C)"
  summary || true
  exit 130
}
trap on_int INT TERM

log_info "Nightly test run: $RUN_ID"
log_info "Root: $ROOT_DIR"

# 1) Bash syntax on all *.sh
if run_with_timeout 120 bash -c '
  cd "$1" || exit 1
  find . -type f -name "*.sh" -print0 | while IFS= read -r -d "" script; do
    [[ -f "$script" ]] || continue
    bash -n "$script" || exit 1
  done
' _ "$ROOT_DIR" 2>"$RUN_DIR/bash-n.err"; then
  ok "bash -n on all scripts"
else
  fail "bash -n failed (see bash-n.err)"
fi

# 2) Repo selftest
if run_with_timeout 120 bash "$ROOT_DIR/scripts/repo_selftest.sh" >"$RUN_DIR/repo_selftest.out" 2>"$RUN_DIR/repo_selftest.err"; then
  ok "repo_selftest passed"
else
  fail "repo_selftest failed (see repo_selftest.*)"
fi

# 3) shellcheck (optional)
if command -v shellcheck >/dev/null 2>&1; then
  if run_with_timeout 300 bash -c '
    cd "$1" || exit 1
    find . -type f -name "*.sh" -print0 | while IFS= read -r -d "" script; do
      [[ -f "$script" ]] || continue
      shellcheck -x "$script" || exit 1
    done
  ' _ "$ROOT_DIR" >"$RUN_DIR/shellcheck.out" 2>"$RUN_DIR/shellcheck.err"; then
    ok "shellcheck clean"
  else
    fail "shellcheck found issues (see shellcheck.*)"
  fi
else
  warn "shellcheck not installed (skipping)"
fi

# 4) shfmt (optional)
if command -v shfmt >/dev/null 2>&1; then
  if run_with_timeout 120 shfmt -d "$ROOT_DIR" >"$RUN_DIR/shfmt.diff" 2>"$RUN_DIR/shfmt.err"; then
    ok "shfmt: no diff"
  else
    warn "shfmt: formatting diff exists (see shfmt.diff)"
  fi
else
  warn "shfmt not installed (skipping)"
fi

# 5) Installer dry-run / resume loop (only if sudo -n works)
ITERATIONS="${NIGHTLY_ITERATIONS:-20}"
if sudo -n true >/dev/null 2>&1; then
  i=1
  while [[ $i -le $ITERATIONS ]]; do
    out="$RUN_DIR/install_dry_run_${i}.out"
    err="$RUN_DIR/install_dry_run_${i}.err"
    if run_with_timeout 600 sudo -n bash "$ROOT_DIR/install.sh" --dry-run --resume >"$out" 2>"$err"; then
      ok "install.sh --dry-run --resume (iter $i/$ITERATIONS)"
    else
      fail "install.sh dry-run failed (iter $i/$ITERATIONS)"
      break
    fi
    i=$((i+1))
  done
else
  warn "sudo -n not available (skipping installer loops)"
fi

summary
