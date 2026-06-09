#!/usr/bin/env bash
# _shim.sh - shared helper sourced by every shim binary.
# Each shim is a 2-line wrapper that sources this file and calls
# shim_dispatch with its own name. A `<name>.conf` next to the shim
# defines the rules.

# shellcheck shell=bash

set -u

SHIM_NAME="${SHIM_NAME:-$(basename "$0")}"
SHIM_DIR="${SHIM_DIR:-$(cd "$(dirname "$0")" && pwd)}"
CONF_FILE="${SHIM_DIR}/../conf/${SHIM_NAME}.conf"
LOG_DIR="${SHIM_LOG_DIR:-$SHIM_DIR/../../bash/.reports}"
LOG_FILE="$LOG_DIR/mock-${SHIM_NAME}.log"
MOCKED_FLAG="${MOCKED_FLAG:-1}"

mkdir -p "$LOG_DIR"

# Defaults overridden by <name>.conf
DEFAULT_EXIT_CODE=0

shim_log_invocation() {
  local args="$*"
  printf '%s|%s|%s\n' "$(date -u +%Y%m%dT%H%M%SZ)" "$SHIM_NAME" "$args" >> "$LOG_FILE"
}

shim_load_conf() {
  if [[ -f "$CONF_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONF_FILE"
  fi
}

shim_dispatch() {
  shim_log_invocation "$*"
  local args="$*"
  local rule stdout exit_code
  for rule in "${SHIM_RULES[@]:-}"; do
    local match="${rule%%:*}"
    if [[ "$args" == *"$match"* ]]; then
      local payload="${rule#*:}"
      stdout="${payload%%|*}"
      exit_code="${payload##*|}"
      [[ -n "$stdout" ]] && printf '%s\n' "$stdout"
      exit "${exit_code:-$DEFAULT_EXIT_CODE}"
    fi
  done
  exit "$DEFAULT_EXIT_CODE"
}

shim_load_conf
shim_dispatch "$@"
