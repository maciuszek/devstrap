#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
DEST_DIR=${DEST_DIR:-"$HOME/.local/share/devstrap"}
BIN_DIR=${BIN_DIR:-"$HOME/bin"}

mkdir -p "$DEST_DIR" "$BIN_DIR"

# Install the runtime tree. Existing install is replaced only inside the
# dedicated devstrap destination; arbitrary user files are never removed.
rm -rf "$DEST_DIR/bin" "$DEST_DIR/templates"
cp -R "$ROOT/bin" "$ROOT/templates" "$DEST_DIR/"

ln -sfn "$DEST_DIR/bin/devstrap" "$BIN_DIR/devstrap"

printf 'Installed devstrap runtime to: %s\n' "$DEST_DIR"
printf 'Command symlink: %s/devstrap -> %s/bin/devstrap\n' "$BIN_DIR" "$DEST_DIR"
printf '\nEnsure %s is on PATH. See docs/NIXOS_INSTALL.md.\n' "$BIN_DIR"
