#!/usr/bin/env bash
set -uo pipefail

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
else
  log_ok()   { printf '[OK]   %s\n' "$*"; }
  log_warn() { printf '[WARN] %s\n' "$*" >&2; }
  log_err()  { printf '[ERR]  %s\n' "$*" >&2; }
  log_info() { printf '[INFO] %s\n' "$*"; }
fi

PASS=0
WARN=0
FAIL=0

UI_LOG_FILE="${RUN_DIR}/nightly.log"

ok()   { PASS=$((PASS+1)); log_ok "$*"; }
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

# ─── 1) Bash syntax on all *.sh ───────────────────────────────────────────
if run_with_timeout 120 bash -c '
  cd "$1" || exit 1
  failed=0
  while IFS= read -r -d "" script; do
    [[ -f "$script" ]] || continue
    if ! bash -n "$script" 2>/tmp/bash_n_err_$$.txt; then
      cat /tmp/bash_n_err_$$.txt >&2
      failed=1
    fi
    rm -f /tmp/bash_n_err_$$.txt
  done < <(find . -type f -name "*.sh" -print0)
  exit $failed
' _ "$ROOT_DIR" 2>"$RUN_DIR/bash-n.err"; then
  ok "bash -n on all scripts"
else
  fail "bash -n failed (see bash-n.err)"
fi

# ─── 2) Repo selftest ─────────────────────────────────────────────────────
if run_with_timeout 120 bash "$ROOT_DIR/scripts/repo_selftest.sh" \
   >"$RUN_DIR/repo_selftest.out" 2>"$RUN_DIR/repo_selftest.err"; then
  ok "repo_selftest passed"
else
  fail "repo_selftest failed (see repo_selftest.*)"
fi

# ─── 3) shellcheck (optional) ─────────────────────────────────────────────
if command -v shellcheck >/dev/null 2>&1; then
  sc_failed=0
  while IFS= read -r -d "" script; do
    [[ -f "$script" ]] || continue
    if ! run_with_timeout 60 shellcheck -x "$script" \
       >>"$RUN_DIR/shellcheck.out" 2>>"$RUN_DIR/shellcheck.err"; then
      sc_failed=1
    fi
  done < <(find "$ROOT_DIR" -type f -name "*.sh" -print0)
  if [[ $sc_failed -eq 0 ]]; then
    ok "shellcheck clean"
  else
    # Degrade to warn (not fail) – shellcheck can be noisy on external/vendor code
    warn "shellcheck found issues (see shellcheck.*)"
  fi
else
  warn "shellcheck not installed (skipping)"
fi

# ─── 4) shfmt (optional) ──────────────────────────────────────────────────
if command -v shfmt >/dev/null 2>&1; then
  if run_with_timeout 120 shfmt -d "$ROOT_DIR" \
     >"$RUN_DIR/shfmt.diff" 2>"$RUN_DIR/shfmt.err"; then
    ok "shfmt: no diff"
  else
    warn "shfmt: formatting diff exists (see shfmt.diff)"
  fi
else
  warn "shfmt not installed (skipping)"
fi

# ─── 5) Installer dry-run / resume loop ───────────────────────────────────
ITERATIONS="${NIGHTLY_ITERATIONS:-3}"
if sudo -n true >/dev/null 2>&1; then
  i=1
  while [[ $i -le $ITERATIONS ]]; do
    out="$RUN_DIR/install_dry_run_${i}.out"
    err="$RUN_DIR/install_dry_run_${i}.err"
    if run_with_timeout 600 sudo -n bash "$ROOT_DIR/install.sh" \
       --dry-run --resume >"$out" 2>"$err"; then
      ok "install.sh --dry-run --resume (iter $i/$ITERATIONS)"
    else
      fail "install.sh dry-run failed (iter $i/$ITERATIONS; see install_dry_run_${i}.*)"
      break
    fi
    i=$((i+1))
  done
else
  warn "sudo -n not available (skipping installer loops)"
fi

# ─── 6) Python suite syntax check ─────────────────────────────────────────
if command -v python3 >/dev/null 2>&1; then
  if run_with_timeout 30 python3 -m py_compile "$ROOT_DIR/start_suite.py" \
     >"$RUN_DIR/py_compile.out" 2>"$RUN_DIR/py_compile.err"; then
    ok "start_suite.py syntax OK"
  else
    fail "start_suite.py syntax error (see py_compile.err)"
  fi
else
  warn "python3 not available (skipping py_compile)"
fi

# ─── 7) requirements.txt sanity ───────────────────────────────────────────
if [[ -f "$ROOT_DIR/requirements.txt" ]]; then
  ok "requirements.txt present"
else
  warn "requirements.txt missing"
fi

summary
