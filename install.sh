#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
DEST_DIR=${DEST_DIR:-"$HOME/.local/share/devstrap"}
BIN_DIR=${BIN_DIR:-"$HOME/bin"}

die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

# DEST_DIR is about to be rm -rf'd; refuse anything that isn't a real,
# specific path so a mistyped/empty override can't turn into `rm -rf /bin`.
[[ "$DEST_DIR" == /* ]] || die "DEST_DIR must be an absolute path: $DEST_DIR"
[[ "$DEST_DIR" != "/" ]] || die "refusing to install to /"

mkdir -p "$DEST_DIR" "$BIN_DIR"

# Install the runtime tree. Existing install is replaced only inside the
# dedicated devstrap destination; arbitrary user files are never removed.
if [[ -e "$DEST_DIR/bin" || -e "$DEST_DIR/templates" ]]; then
  printf 'This will remove and replace:\n'
  [[ -e "$DEST_DIR/bin" ]] && printf '  %s\n' "$DEST_DIR/bin"
  [[ -e "$DEST_DIR/templates" ]] && printf '  %s\n' "$DEST_DIR/templates"
  read -r -p "Continue? [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]] || die "aborted"
fi

rm -rf "${DEST_DIR:?}/bin" "${DEST_DIR:?}/templates"
cp -R "$ROOT/bin" "$ROOT/templates" "$DEST_DIR/"

ln -sfn "$DEST_DIR/bin/devstrap" "$BIN_DIR/devstrap"

printf 'Installed devstrap runtime to: %s\n' "$DEST_DIR"
printf 'Command symlink: %s/devstrap -> %s/bin/devstrap\n' "$BIN_DIR" "$DEST_DIR"
printf '\nEnsure %s is on PATH. See docs/NIXOS_INSTALL.md.\n' "$BIN_DIR"
