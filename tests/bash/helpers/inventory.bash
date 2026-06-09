#!/usr/bin/env bash
# inventory.bash - enumerate the script inventory for the bash test suite.
# Sources the excluded-scripts allowlist and produces a sorted, deduplicated list.

# shellcheck shell=bash

set -u

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"

inventory_categories() {
  local category="$1"; shift
  case "$category" in
    root) printf '%s\n' entrypoint.sh; ls "$REPO_ROOT"/*.sh 2>/dev/null | sed "s|^$REPO_ROOT/||" ;;
    module) find "$REPO_ROOT/modules" -mindepth 2 -maxdepth 2 -name module.sh -type f 2>/dev/null | sed "s|^$REPO_ROOT/||" ;;
    utility) find "$REPO_ROOT/utils" -maxdepth 1 -name "*.sh" -type f 2>/dev/null | sed "s|^$REPO_ROOT/||" ;;
    *) return 1 ;;
  esac
}

inventory_excluded() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  while IFS= read -r line; do
    line="${line%%#*}"
    line="${line## }"
    line="${line%% }"
    [[ -n "$line" ]] && printf '%s\n' "$line"
  done < "$file"
}

inventory_is_excluded() {
  local script_path="$1"
  local excluded_file="$2"
  [[ -f "$excluded_file" ]] || return 1
  while IFS= read -r pattern; do
    [[ -z "$pattern" ]] && continue
    [[ "$script_path" == "$pattern" ]] && return 0
  done < <(inventory_excluded "$excluded_file")
  return 1
}

# Public: inventory_list <excluded-file> [category...]
# Prints one path per line, sorted, deduplicated, with excluded entries removed.
inventory_list() {
  local excluded_file="${1:-$REPO_ROOT/tests/bash/excluded-scripts.bash}"
  shift || true
  local categories=("$@")
  if [[ ${#categories[@]} -eq 0 ]]; then
    categories=(root module utility)
  fi
  {
    for cat in "${categories[@]}"; do
      inventory_categories "$cat"
    done
  } | sort -u | while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    if inventory_is_excluded "$path" "$excluded_file"; then
      continue
    fi
    printf '%s\n' "$path"
  done | sort -u
}
