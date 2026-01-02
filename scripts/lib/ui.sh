#!/usr/bin/env bash

# Shared UI helpers for this repo.
# - Centralizes color handling (TTY + NO_COLOR)
# - Provides consistent log_* helpers
# - Avoids echo -e; uses printf

ui_init() {
  UI_COLOR=true

  if [[ ! -t 1 ]]; then
    UI_COLOR=false
  fi
  if [[ -n "${NO_COLOR:-}" ]]; then
    UI_COLOR=false
  fi

  if [[ "$UI_COLOR" == true ]]; then
    UI_RED=$'\033[0;31m'
    UI_GREEN=$'\033[0;32m'
    UI_YELLOW=$'\033[1;33m'
    UI_BLUE=$'\033[0;34m'
    UI_MAGENTA=$'\033[0;35m'
    UI_CYAN=$'\033[0;36m'
    UI_BOLD=$'\033[1m'
    UI_RESET=$'\033[0m'
  else
    UI_RED='' UI_GREEN='' UI_YELLOW='' UI_BLUE='' UI_MAGENTA='' UI_CYAN='' UI_BOLD='' UI_RESET=''
  fi
}

_ui_ts() {
  date +"%H:%M:%S"
}

_ui_format_line() {
  local label="$1"
  local color="$2"
  local msg="$3"

  if [[ "${UI_COLOR:-false}" == true && -n "$color" ]]; then
    printf '[%s] %s%s%s %s' "$(_ui_ts)" "$color" "$label" "$UI_RESET" "$msg"
  else
    printf '[%s] %s %s' "$(_ui_ts)" "$label" "$msg"
  fi
}

_ui_write_log() {
  local label="$1"
  local msg="$2"
  local target="$3"
  local line

  [[ -z "$target" ]] && return 0
  if [[ ! -w "$(dirname "$target")" ]]; then
    return 0
  fi
  line="$(_ui_format_line "$label" "" "$msg")"
  printf '%s\n' "$line" >> "$target" 2>/dev/null || true
}

log_info() {
  local msg="$*"
  printf '%s\n' "$(_ui_format_line "INFO" "$UI_BLUE" "$msg")"
  _ui_write_log "INFO" "$msg" "${UI_LOG_FILE:-}"
}

# Canonical success + error names for this repo (see AGENTS.md)
log_ok() {
  local msg="$*"
  printf '%s\n' "$(_ui_format_line "OK" "$UI_GREEN" "$msg")"
  _ui_write_log "OK" "$msg" "${UI_LOG_FILE:-}"
}

log_warn() {
  local msg="$*"
  printf '%s\n' "$(_ui_format_line "WARN" "$UI_YELLOW" "$msg")" >&2
  _ui_write_log "WARN" "$msg" "${UI_LOG_FILE:-}"
}

log_err() {
  local msg="$*"
  printf '%s\n' "$(_ui_format_line "ERR" "$UI_RED" "$msg")" >&2
  _ui_write_log "ERR" "$msg" "${UI_LOG_FILE:-}"
  _ui_write_log "ERR" "$msg" "${UI_ERROR_LOG:-}"
}

# Backwards-compatible aliases (avoid churn in callers while refactoring)
log_success() { log_ok "$@"; }
log_error() { log_err "$@"; }

ui_hr() {
  local ch='-'
  local n=65
  printf '%*s\n' "$n" '' | tr ' ' "$ch"
}

ui_header() {
  ui_hr
  printf '%s%s%s\n' "$UI_BOLD" "$*" "$UI_RESET"
  ui_hr
}

ui_label() {
  local label="$1"
  local color="$2"
  if [[ "${UI_COLOR:-false}" == true && -n "$color" ]]; then
    printf '%s[%s]%s' "$color" "$label" "$UI_RESET"
  else
    printf '[%s]' "$label"
  fi
}

ui_section() {
  printf '\n%s=== %s ===%s\n' "$UI_BLUE" "$*" "$UI_RESET"
}

ui_pass() {
  printf '%s %s\n' "$(ui_label "PASS" "$UI_GREEN")" "$*"
}

ui_warn() {
  printf '%s %s\n' "$(ui_label "WARN" "$UI_YELLOW")" "$*"
}

ui_fail() {
  printf '%s %s\n' "$(ui_label "FAIL" "$UI_RED")" "$*"
}

ui_info() {
  printf '%s %s\n' "$(ui_label "INFO" "$UI_BLUE")" "$*"
}

ui_dir_not_empty() {
  local dir="$1"
  if [[ -d "$dir" ]] && find "$dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null | grep -q .; then
    return 0
  fi
  return 1
}

ui_confirm() {
  local prompt="$1"
  local answer=""
  printf '%s%s%s\n' "$UI_YELLOW" "$prompt" "$UI_RESET"
  read -r -p "Continue? [y/N]: " answer
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

ui_pause() {
  printf '\n'
  read -r -p "Press ENTER to continue..."
}
