#!/usr/bin/env bash
set -euo pipefail

# =============================================
# PI-HOLE SUITE CONSOLE MENU
# Interactive management interface
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

# =============================================
# HELPER FUNCTIONS
# =============================================
header() {
  clear
  echo -e "${BLUE}┌─────────────────────────────────────────────────────────────────┐${NC}"
  echo -e "${BLUE}│${NC}          ${BOLD}Pi-hole + Unbound Management Suite v${VERSION}${NC}          ${BLUE}│${NC}"
  echo -e "${BLUE}└─────────────────────────────────────────────────────────────────┘${NC}"
  echo ""
}

confirm() {
  local prompt="$1"
  echo -e "${YELLOW}${prompt}${NC}"
  read -rp "Continue? [y/N]: " choice
  case "$choice" in
    y|Y|yes|YES) return 0 ;;
    *) echo -e "${RED}Cancelled.${NC}"; return 1 ;;
  esac
}

pause() {
  echo ""
  read -rp "Press ENTER to continue..."
}

# =============================================
# MENU ACTIONS
# =============================================
action_quick_check() {
  header
  echo -e "${GREEN}Running Quick Check...${NC}"
  echo ""
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
    echo -e "${RED}Error: Maintenance Pro script not found at:${NC}"
    echo "  $maint_script"
    pause
    return 1
  fi

  echo -e "${YELLOW}⚠️  WARNING: Maintenance Pro performs system modifications${NC}"
  echo ""
  echo "This tool will:"
  echo "  - Update package lists"
  echo "  - Upgrade Pi-hole components"
  echo "  - Clean temporary files"
  echo "  - Restart services"
  echo ""
  echo -e "${BOLD}This requires sudo privileges.${NC}"
  echo ""

  if confirm "Run Maintenance Pro in SAFE mode?"; then
    echo ""
    sudo "$maint_script"
  fi
  pause
}

action_view_logs() {
  header
  echo -e "${BLUE}Available Logs:${NC}"
  echo ""

  local logs_found=false

  # Check for maintenance logs
  if ls /var/log/pihole_maintenance_pro_*.log &>/dev/null 2>&1; then
    logs_found=true
    echo "Maintenance Pro logs:"
    ls -lh /var/log/pihole_maintenance_pro_*.log 2>/dev/null | tail -n 5
    echo ""
  fi

  # Check for repo logs
  if [[ -d "$REPO_ROOT/logs" ]] && ls "$REPO_ROOT/logs"/*.log &>/dev/null 2>&1; then
    logs_found=true
    echo "Repository logs:"
    ls -lh "$REPO_ROOT/logs"/*.log 2>/dev/null
    echo ""
  fi

  if ! $logs_found; then
    echo -e "${YELLOW}No logs found.${NC}"
    pause
    return
  fi

  echo "Select a log to view:"
  echo "  [1] Latest maintenance log"
  echo "  [2] View all systemd journal (pihole-FTL)"
  echo "  [3] View all systemd journal (unbound)"
  echo "  [0] Back to menu"
  echo ""
  read -rp "Choice: " log_choice

  case "$log_choice" in
    1)
      local latest_log
      latest_log=$(ls -t /var/log/pihole_maintenance_pro_*.log 2>/dev/null | head -n1 || echo "")
      if [[ -n "$latest_log" ]]; then
        if command -v less &>/dev/null; then
          sudo less "$latest_log"
        else
          sudo cat "$latest_log"
          pause
        fi
      else
        echo -e "${RED}No maintenance logs found.${NC}"
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
      echo -e "${RED}Invalid choice.${NC}"
      pause
      ;;
  esac
}

action_check_mode() {
  # Non-interactive mode for validation
  local all_ok=true

  # Check if dialog is available
  if ! command -v dialog &>/dev/null; then
    echo "[INFO] dialog not installed (optional, fallback to text menu available)"
  fi

  # Check scripts exist
  if [[ ! -f "$SCRIPT_DIR/post_install_check.sh" ]]; then
    echo "[FAIL] post_install_check.sh not found"
    all_ok=false
  else
    echo "[PASS] post_install_check.sh found"
  fi

  if [[ ! -f "$REPO_ROOT/tools/pihole_maintenance_pro.sh" ]]; then
    echo "[WARN] pihole_maintenance_pro.sh not found (optional)"
  else
    echo "[PASS] pihole_maintenance_pro.sh found"
  fi

  # Check if menu can start
  echo "[INFO] Console menu available (text mode)"

  if $all_ok; then
    echo "[PASS] Console menu check completed"
    return 0
  else
    echo "[FAIL] Console menu check failed"
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
    echo "Select an option:"
    echo ""
    echo "  [1] Post-Install Check (Quick)"
    echo "  [2] Post-Install Check (Full) - requires sudo"
    echo "  [3] Show Service URLs"
    echo "  [4] Manual Steps Guide"
    echo "  [5] Maintenance Pro (SAFE mode) - requires sudo"
    echo "  [6] View Logs"
    echo "  [7] Exit"
    echo ""
    read -rp "Choice [1-7]: " choice

    case $choice in
      1) action_quick_check ;;
      2) action_full_check ;;
      3) action_show_urls ;;
      4) action_manual_steps ;;
      5) action_maintenance_pro ;;
      6) action_view_logs ;;
      7) clear; echo "Goodbye!"; exit 0 ;;
      "") continue ;;
      *)
        echo -e "${RED}Invalid choice. Please select 1-7.${NC}"
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
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Run with --help for usage information."
      exit 1
      ;;
  esac
}

main "$@"
