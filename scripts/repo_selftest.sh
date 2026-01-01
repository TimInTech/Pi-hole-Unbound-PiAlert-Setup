#!/usr/bin/env bash
set -euo pipefail

# =============================================
# REPOSITORY SELF-TEST SCRIPT
# Validates repository integrity before deployment
# =============================================

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

# Counters
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# =============================================
# HELPER FUNCTIONS
# =============================================
pass() {
  echo -e "${GREEN}[PASS]${NC} $*"
  PASS_COUNT=$((PASS_COUNT + 1))
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
  WARN_COUNT=$((WARN_COUNT + 1))
}

fail() {
  echo -e "${RED}[FAIL]${NC} $*"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

section() {
  echo ""
  echo -e "${BLUE}=== $* ===${NC}"
}


is_git_repo() {
  command -v git &>/dev/null || return 1
  git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

list_shell_scripts() {
  cd "$REPO_ROOT" || return 1
  if is_git_repo; then
    git -C "$REPO_ROOT" ls-files '*.sh'
  else
    find . -type f -name '*.sh' -print | sed 's|^\./||'
  fi
}

# =============================================
# TEST FUNCTIONS
# =============================================
test_bash_syntax() {
  section "Bash Syntax Checks"

  cd "$REPO_ROOT"

  while IFS= read -r script; do
    if [[ ! -f "$script" ]]; then
      warn "Script not found: $script"
      continue
    fi

    if bash -n "$script" 2>/dev/null; then
      pass "Syntax OK: $script"
    else
      fail "Syntax ERROR: $script"
    fi
  done < <(list_shell_scripts)
}

test_executable_bits() {
  section "Executable Permissions Check"

  cd "$REPO_ROOT"

  while IFS= read -r script; do
    if [[ ! -f "$script" ]]; then
      warn "Script not found: $script"
      continue
    fi

    # Check git index mode
    if is_git_repo && git -C "$REPO_ROOT" ls-files --error-unmatch "$script" &>/dev/null 2>&1; then
      local mode
      mode=$(git -C "$REPO_ROOT" ls-files -s "$script" | awk '{print $1}')
      if [[ "$mode" == "100755" ]]; then
        pass "Executable in git: $script"
      else
        fail "NOT executable in git (mode: $mode): $script"
      fi
    else
      # Not in git, check filesystem
      if [[ -x "$script" ]]; then
        pass "Executable on filesystem: $script"
      else
        warn "NOT executable on filesystem: $script"
      fi
    fi
  done < <(list_shell_scripts)
}

test_line_endings() {
  section "Line Endings Check (CRLF Detection)"

  cd "$REPO_ROOT"

  while IFS= read -r script; do
    if [[ ! -f "$script" ]]; then
      continue
    fi

    # Quick check for CR characters (no slow file command)
    if grep -q $'\r' "$script" 2>/dev/null; then
      fail "CRLF/CR line endings detected: $script"
    else
      pass "Line endings OK: $script"
    fi
  done < <(list_shell_scripts)
}

test_readme_code_fences() {
  section "README Code Fence Balance Check"

  cd "$REPO_ROOT"

  # Use Python for accurate fence checking
  if ! command -v python3 &>/dev/null; then
    warn "python3 not available, using simple grep fallback"

    for readme in README.md README.de.md; do
      if [[ ! -f "$readme" ]]; then
        warn "README not found: $readme"
        continue
      fi

      local fence_count
      fence_count=$(grep -c '^```' "$readme" 2>/dev/null || echo 0)

      if (( fence_count % 2 == 0 )); then
        pass "Code fences balanced in $readme (count: $fence_count)"
      else
        fail "Code fences UNBALANCED in $readme (count: $fence_count)"
      fi
    done
    return
  fi

  # Python-based check (more reliable)
  python3 - <<'PY'
import pathlib
import sys

all_ok = True
for f in ['README.md', 'README.de.md']:
    p = pathlib.Path(f)
    if not p.exists():
        print(f"[WARN] README not found: {f}")
        continue

    t = p.read_text(encoding='utf-8', errors='replace')
    n = t.count('```')

    if n % 2 == 0:
        print(f"[PASS] Code fences balanced in {f} (count: {n})")
    else:
        print(f"[FAIL] Code fences UNBALANCED in {f} (count: {n})")
        all_ok = False

sys.exit(0 if all_ok else 1)
PY

  if [[ $? -eq 0 ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

test_required_files() {
  section "Required Files Check"

  cd "$REPO_ROOT" || return 1

  local file
  for file in install.sh README.md README.de.md scripts/post_install_check.sh scripts/console_menu.sh .gitignore; do
    if [[ -f "$file" ]]; then
      pass "Required file exists: $file"
    else
      fail "Required file MISSING: $file"
    fi
  done
}

test_optional_files() {
  section "Optional Files Check"

  cd "$REPO_ROOT" || return 1

  local file
  for file in tools/pihole_maintenance_pro.sh docs/CONSOLE_MENU.md; do
    if [[ -f "$file" ]]; then
      info "Optional file present: $file"
    else
      warn "Optional file missing: $file"
    fi
  done
}

test_script_shebangs() {
  section "Shebang Check"

  local scripts=(
    "$REPO_ROOT/install.sh"
    "$SCRIPT_DIR/post_install_check.sh"
    "$SCRIPT_DIR/console_menu.sh"
  )

  for script in "${scripts[@]}"; do
    if [[ ! -f "$script" ]]; then
      continue
    fi

    local shebang
    shebang=$(head -n1 "$script")

    if [[ "$shebang" =~ ^#!/usr/bin/env\ bash$ ]] || [[ "$shebang" =~ ^#!/bin/bash$ ]]; then
      pass "Valid shebang: $(basename "$script")"
    else
      fail "Invalid/missing shebang in $(basename "$script"): $shebang"
    fi
  done
}

test_portable_commands() {
  section "Portable Command Check"

  local scripts=(
    "$REPO_ROOT/install.sh"
  )

  for script in "${scripts[@]}"; do
    if [[ ! -f "$script" ]]; then
      continue
    fi

    # Check for non-portable \s in regex
    if grep -n 'sed.*\\s' "$script" | grep -v '\[[:space:\]\]' >/dev/null 2>&1; then
      fail "Non-portable \\s regex found in $(basename "$script")"
    else
      pass "Portable regex patterns in $(basename "$script")"
    fi
  done
}

# =============================================
# SUMMARY
# =============================================
print_summary() {
  echo ""
  echo "┌─────────────────────────────────────────────────────────────────┐"
  echo "│                    Repository Self-Test Summary                │"
  echo "├─────────────────────────────────────────────────────────────────┤"
  printf "│ ${GREEN}PASS:${NC} %-57s│\n" "$PASS_COUNT"
  printf "│ ${YELLOW}WARN:${NC} %-57s│\n" "$WARN_COUNT"
  printf "│ ${RED}FAIL:${NC} %-57s│\n" "$FAIL_COUNT"
  echo "└─────────────────────────────────────────────────────────────────┘"
  echo ""

  if [[ $FAIL_COUNT -gt 0 ]]; then
    echo -e "${RED}Repository self-test FAILED. Please fix the issues above.${NC}"
    return 1
  elif [[ $WARN_COUNT -gt 0 ]]; then
    echo -e "${YELLOW}Repository self-test passed with warnings.${NC}"
    return 0
  else
    echo -e "${GREEN}Repository self-test PASSED!${NC}"
    return 0
  fi
}

# =============================================
# MAIN
# =============================================
main() {
  echo "┌─────────────────────────────────────────────────────────────────┐"
  echo "│           Repository Self-Test - Pre-Deployment Check          │"
  echo "│                         Version $VERSION                          │"
  echo "└─────────────────────────────────────────────────────────────────┘"

  test_required_files
  test_bash_syntax
  test_executable_bits
  test_line_endings
  test_readme_code_fences
  test_script_shebangs
  test_portable_commands
  test_optional_files

  print_summary
}

main "$@"
