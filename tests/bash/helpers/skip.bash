#!/usr/bin/env bash
# skip.bash - missing-tool detection and skip-with-reason helpers.

# shellcheck shell=bash

set -u

# command_exists <tool>
# Returns 0 when <tool> is on PATH.
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# missing_tool_reason <tool>...
# Prints a single-line reason beginning with "missing tool: <name>".
# If multiple tools are missing, the first is named.
# Always returns 0; callers can check the printed reason with [ -n "$reason" ].
missing_tool_reason() {
  local tool
  for tool in "$@"; do
    if ! command_exists "$tool"; then
      printf 'missing tool: %s' "$tool"
      return 0
    fi
  done
  return 0
}

# skip_with_reason <reason>
# Emits a bats "skip" line using the standard `skip` builtin when available.
skip_with_reason() {
  local reason="$1"
  if declare -F skip >/dev/null 2>&1; then
    skip "$reason"
  else
    printf 'bats: skip %s\n' "$reason"
  fi
}

# skip_if_missing_tools <tool>...
# Skips the current test (bats) when any of the named tools is missing.
# Returns 0 (skipped) when at least one tool is missing, 1 otherwise.
skip_if_missing_tools() {
  local reason
  reason=$(missing_tool_reason "$@")
  if [[ -n "$reason" ]]; then
    skip_with_reason "$reason"
    return 0
  fi
  return 1
}
