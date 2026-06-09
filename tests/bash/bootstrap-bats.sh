#!/usr/bin/env bash
# bootstrap-bats.sh - install a pinned bats into tests/bash/.bats/ on first run.
# Idempotent: a no-op when the local bats is already in place.

set -u

BATS_BOOTSTRAP_VERSION="${BATS_BOOTSTRAP_VERSION:-1.11.0}"
BATS_LOCAL_DIR="${BATS_LOCAL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.bats}"
BATS_BIN="$BATS_LOCAL_DIR/install/bin/bats"
BATS_VERSION_FILE="$BATS_LOCAL_DIR/VERSION"

log() { printf '[bootstrap-bats] %s\n' "$*"; }

already_installed() {
  [[ -x "$BATS_BIN" && -f "$BATS_VERSION_FILE" ]] || return 1
  local installed
  installed=$(cat "$BATS_VERSION_FILE" 2>/dev/null || true)
  [[ "$installed" == "$BATS_BOOTSTRAP_VERSION" ]]
}

install_bats() {
  local archive="bats-core-${BATS_BOOTSTRAP_VERSION}.tar.gz"
  local url="https://github.com/bats-core/bats-core/archive/refs/tags/v${BATS_BOOTSTRAP_VERSION}.tar.gz"
  local tarball="$BATS_LOCAL_DIR/$archive"
  local source_dir="$BATS_LOCAL_DIR/bats-core-${BATS_BOOTSTRAP_VERSION}"
  local install_dir="$BATS_LOCAL_DIR/install"

  mkdir -p "$BATS_LOCAL_DIR"
  if ! already_installed; then
    log "bats not present or version mismatch; downloading $url"
    if ! command -v curl >/dev/null 2>&1; then
      log "ERROR: curl is required for the first run; install curl or bats manually."
      return 1
    fi
    if ! curl -fsSL -o "$tarball" "$url"; then
      log "ERROR: failed to download bats ${BATS_BOOTSTRAP_VERSION} from $url"
      return 1
    fi
    if ! tar -xzf "$tarball" -C "$BATS_LOCAL_DIR"; then
      log "ERROR: failed to extract $tarball"
      return 1
    fi
    log "installing bats into $install_dir"
    if ! "$source_dir/install.sh" "$install_dir" >/dev/null; then
      log "ERROR: bats install.sh failed"
      return 1
    fi
    printf '%s\n' "$BATS_BOOTSTRAP_VERSION" > "$BATS_VERSION_FILE"
    rm -rf "$source_dir" "$tarball"
  fi
  log "bats ${BATS_BOOTSTRAP_VERSION} available at $BATS_BIN"
}

if [[ "${1:-}" == "--print-path" ]]; then
  already_installed || install_bats
  printf '%s\n' "$BATS_BIN"
  exit 0
fi

if ! already_installed; then
  install_bats
else
  log "bats ${BATS_BOOTSTRAP_VERSION} already installed at $BATS_BIN"
fi
