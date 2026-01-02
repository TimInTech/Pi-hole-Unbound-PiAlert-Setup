#!/usr/bin/env bash
set -euo pipefail

# =============================================
# PI-HOLE SUITE CONSOLE MENU
# Interactive management interface
# =============================================

VERSION="1.0.0"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
UI_LIB="${SCRIPT_DIR}/lib/ui.sh"
if [[ -f "$UI_LIB" ]]; then
  # shellcheck source=/dev/null
  source "$UI_LIB"
  ui_init
fi

# =============================================
# HELPER FUNCTIONS
# =============================================
header() {
  clear
  printf '%s┌─────────────────────────────────────────────────────────────────┐%s\n' "$UI_BLUE" "$UI_RESET"
  printf '%s│%s          %sPi-hole + Unbound Management Suite v%s%s          %s│%s\n' \
    "$UI_BLUE" "$UI_RESET" "$UI_BOLD" "$VERSION" "$UI_RESET" "$UI_BLUE" "$UI_RESET"
  printf '%s└─────────────────────────────────────────────────────────────────┘%s\n' "$UI_BLUE" "$UI_RESET"
  printf '\n'
}

confirm() {
  local prompt="$1"
  if ui_confirm "$prompt"; then
    return 0
  fi
  printf '%sCancelled.%s\n' "$UI_RED" "$UI_RESET"
  return 1
}

pause() {
  ui_pause
}

# =============================================
# MENU ACTIONS
# =============================================
action_quick_check() {
  header
  printf '%sRunning Quick Check...%s\n\n' "$UI_GREEN" "$UI_RESET"
  "$SCRIPT_DIR/post_install_check.sh" --quick
  pause
}

action_full_check() {
  header
  if confirm "This will run a comprehensive system check (requires sudo)."; then
    echo ""
    sudo "$SCRIPT_DIR/post_install_check.sh" --full
  fi
  pause
}

action_show_urls() {
  header
  "$SCRIPT_DIR/post_install_check.sh" --urls
  pause
}

action_manual_steps() {
  header
  if command -v less &>/dev/null; then
    "$SCRIPT_DIR/post_install_check.sh" --steps | less
  else
    "$SCRIPT_DIR/post_install_check.sh" --steps
    pause
  fi
}

action_maintenance_pro() {
  header
  local maint_script="$REPO_ROOT/tools/pihole_maintenance_pro.sh"

  if [[ ! -f "$maint_script" ]]; then
    printf '%sError: Maintenance Pro script not found at:%s\n' "$UI_RED" "$UI_RESET"
    printf '  %s\n' "$maint_script"
    pause
    return 1
  fi

  printf '%s⚠️  WARNING: Maintenance Pro performs system modifications%s\n\n' "$UI_YELLOW" "$UI_RESET"
  printf '%s\n' "This tool will:"
  printf '%s\n' "  - Update package lists"
  printf '%s\n' "  - Upgrade Pi-hole components"
  printf '%s\n' "  - Clean temporary files"
  printf '%s\n' "  - Restart services"
  printf '\n'
  printf '%sThis requires sudo privileges.%s\n\n' "$UI_BOLD" "$UI_RESET"

  if confirm "Run Maintenance Pro in SAFE mode?"; then
    echo ""
    sudo "$maint_script"
  fi
  pause
}

action_view_logs() {
  header
  printf '%sAvailable Logs:%s\n\n' "$UI_BLUE" "$UI_RESET"

  local logs_found=false
  local log_files=()
  local log=""
  local latest_log=""
  local nullglob_was_set=1

  shopt -q nullglob || nullglob_was_set=0
  shopt -s nullglob

  # Check for maintenance logs
  log_files=(/var/log/pihole_maintenance_pro_*.log)
  if (( ${#log_files[@]} > 0 )); then
    logs_found=true
    printf '%s\n' "Maintenance Pro logs:"
    for log in "${log_files[@]:0:5}"; do
      if [[ -f "$log" ]]; then
        ls -lh "$log" 2>/dev/null || printf '  %s\n' "$log"
      fi
    done
    printf '\n'
  fi

  # Check for repo logs
  if [[ -d "$REPO_ROOT/logs" ]]; then
    log_files=("$REPO_ROOT/logs"/*.log)
    if (( ${#log_files[@]} > 0 )); then
      logs_found=true
      printf '%s\n' "Repository logs:"
      for log in "${log_files[@]}"; do
        if [[ -f "$log" ]]; then
          ls -lh "$log" 2>/dev/null || printf '  %s\n' "$log"
        fi
      done
      printf '\n'
    fi
  fi

  if [[ "$nullglob_was_set" -eq 0 ]]; then
    shopt -u nullglob
  fi

  if ! $logs_found; then
    printf '%sNo logs found.%s\n' "$UI_YELLOW" "$UI_RESET"
    pause
    return
  fi

  printf '%s\n' "Select a log to view:"
  printf '%s\n' "  [1] Latest maintenance log"
  printf '%s\n' "  [2] View all systemd journal (pihole-FTL)"
  printf '%s\n' "  [3] View all systemd journal (unbound)"
  printf '%s\n' "  [0] Back to menu"
  printf '\n'
  IFS= read -rp "Choice: " log_choice

  case "$log_choice" in
    1)
      nullglob_was_set=1
      shopt -q nullglob || nullglob_was_set=0
      shopt -s nullglob
      log_files=(/var/log/pihole_maintenance_pro_*.log)
      for log in "${log_files[@]}"; do
        if [[ -f "$log" ]]; then
          if [[ -z "$latest_log" || "$log" -nt "$latest_log" ]]; then
            latest_log="$log"
          fi
        fi
      done
      if [[ "$nullglob_was_set" -eq 0 ]]; then
        shopt -u nullglob
      fi
      if [[ -n "$latest_log" ]]; then
        if command -v less &>/dev/null; then
          sudo less "$latest_log"
        else
          sudo cat "$latest_log"
          pause
        fi
      else
        printf '%sNo maintenance logs found.%s\n' "$UI_RED" "$UI_RESET"
        pause
      fi
      ;;
    2)
      sudo journalctl -u pihole-FTL -n 100 --no-pager
      pause
      ;;
    3)
      sudo journalctl -u unbound -n 100 --no-pager
      pause
      ;;
    0|"")
      return
      ;;
    *)
      printf '%sInvalid choice.%s\n' "$UI_RED" "$UI_RESET"
      pause
      ;;
  esac
}

action_check_mode() {
  # Non-interactive mode for validation
  local all_ok=true

  # Check if dialog is available
  if ! command -v dialog &>/dev/null; then
    log_info "dialog not installed (optional, fallback to text menu available)"
  fi

  # Check scripts exist
  if [[ ! -f "$SCRIPT_DIR/post_install_check.sh" ]]; then
    log_err "post_install_check.sh not found"
    all_ok=false
  else
    log_ok "post_install_check.sh found"
  fi

  if [[ ! -f "$REPO_ROOT/tools/pihole_maintenance_pro.sh" ]]; then
    log_warn "pihole_maintenance_pro.sh not found (optional)"
  else
    log_ok "pihole_maintenance_pro.sh found"
  fi

  # Check if menu can start
  log_info "Console menu available (text mode)"

  if $all_ok; then
    log_ok "Console menu check completed"
    return 0
  else
    log_err "Console menu check failed"
    return 1
  fi
}

# =============================================
# DIALOG-BASED MENU (if available)
# =============================================
show_dialog_menu() {
  if ! command -v dialog &>/dev/null; then
    return 1
  fi

  while true; do
    local choice
    choice=$(dialog --clear --title "Pi-hole Suite Management" \
      --menu "Select an option:" 15 65 7 \
      1 "Quick Check (summary)" \
      2 "Full Check (comprehensive, requires sudo)" \
      3 "Show Service URLs" \
      4 "Manual Steps Guide" \
      5 "Maintenance Pro (SAFE mode)" \
      6 "View Logs" \
      7 "Exit" \
      2>&1 >/dev/tty) || return 0

    clear
    case $choice in
      1) action_quick_check ;;
      2) action_full_check ;;
      3) action_show_urls ;;
      4) action_manual_steps ;;
      5) action_maintenance_pro ;;
      6) action_view_logs ;;
      7) clear; exit 0 ;;
    esac
  done
}

# =============================================
# TEXT-BASED MENU (fallback)
# =============================================
show_text_menu() {
  while true; do
    header
    printf '%s\n\n' "Select an option:"
    printf '%s\n' "  [1] Post-Install Check (Quick)"
    printf '%s\n' "  [2] Post-Install Check (Full) - requires sudo"
    printf '%s\n' "  [3] Show Service URLs"
    printf '%s\n' "  [4] Manual Steps Guide"
    printf '%s\n' "  [5] Maintenance Pro (SAFE mode) - requires sudo"
    printf '%s\n' "  [6] View Logs"
    printf '%s\n\n' "  [7] Exit"
    IFS= read -rp "Choice [1-7]: " choice

    case $choice in
      1) action_quick_check ;;
      2) action_full_check ;;
      3) action_show_urls ;;
      4) action_manual_steps ;;
      5) action_maintenance_pro ;;
      6) action_view_logs ;;
      7) clear; printf '%s\n' "Goodbye!"; exit 0 ;;
      "") continue ;;
      *)
        printf '%sInvalid choice. Please select 1-7.%s\n' "$UI_RED" "$UI_RESET"
        sleep 1
        ;;
    esac
  done
}

# =============================================
# MAIN
# =============================================
main() {
  case "${1:-}" in
    --check)
      action_check_mode
      exit $?
      ;;
    -h|--help)
      cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Interactive management console for Pi-hole + Unbound suite.

OPTIONS:
  --check       Run non-interactive check mode
  -h, --help    Show this help message

INTERACTIVE MODE:
  Run without arguments to start the interactive menu.

NOTE:
  If 'dialog' is installed, a graphical menu will be used.
  Otherwise, a text-based menu will be shown.
  Install dialog: sudo apt-get install -y dialog

EOF
      exit 0
      ;;
    "")
      # Try dialog menu first, fall back to text
      if ! show_dialog_menu; then
        show_text_menu
      fi
      ;;
    *)
      printf '%sUnknown option: %s%s\n' "$UI_RED" "$1" "$UI_RESET"
      printf '%s\n' "Run with --help for usage information."
      exit 1
      ;;
  esac
}

main "$@"
