#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
DEST_DIR=${DEST_DIR:-"$HOME/.local/share/devstrap"}
BIN_DIR=${BIN_DIR:-"$HOME/bin"}
MODE="link"

usage() {
  cat <<'EOF'
Usage: install.sh [--link | --standalone]

  --link        Default. Point the command at this checkout, so edits here --
                including new templates -- are picked up with no reinstall.
                The checkout must stay where it is.
  --standalone  Copy bin/ and templates/ into their own runtime directory and
                point the command there, so the install no longer depends on
                this checkout. Re-run to pick up changes.

Both modes create the same command symlink; they differ only in what it points
at. Environment overrides: BIN_DIR (command directory), DEST_DIR (standalone
runtime directory).
EOF
}

die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

confirm() {
  local reply
  read -r -p "$1 [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]] || die "aborted"
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --link) MODE="link"; shift ;;
    --standalone) MODE="standalone"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'install.sh: unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

# Both modes depend on a complete checkout: --link points the command at it
# permanently, and --standalone copies from it after replacing an existing
# install. Checking first means a partial checkout fails before anything moves.
[[ -f "$ROOT/bin/devstrap" ]] || die "missing runtime: $ROOT/bin/devstrap"
[[ -x "$ROOT/bin/devstrap" ]] || die "runtime is not executable: $ROOT/bin/devstrap"
[[ -d "$ROOT/templates" ]] || die "missing templates directory: $ROOT/templates"

LINK="$BIN_DIR/devstrap"

# Gate for the command symlink, shared by both modes and always run before that
# mode's first filesystem change, so declining leaves everything as it was.
# `ln -sfn` would replace an unrelated file without asking, and would quietly
# create $LINK/devstrap if $LINK were a real directory.
preflight_link() {
  local target=$1 current

  if [[ -d "$LINK" && ! -L "$LINK" ]]; then
    die "refusing to replace directory: $LINK"
  fi

  if [[ -L "$LINK" ]]; then
    current=$(readlink -- "$LINK")
    if [[ "$current" != "$target" ]]; then
      printf 'This will repoint the existing command symlink:\n'
      printf '  %s -> %s\n' "$LINK" "$current"
      printf 'to:\n'
      printf '  %s -> %s\n' "$LINK" "$target"
      confirm "Continue?"
    fi
  elif [[ -e "$LINK" ]]; then
    printf 'This will replace the existing file:\n  %s\n' "$LINK"
    confirm "Continue?"
  fi
}

# Sole writer of the command symlink; only ever called after preflight_link.
write_link() {
  mkdir -p "$BIN_DIR"
  ln -sfn "$1" "$LINK"
}

if [[ "$MODE" == standalone ]]; then
  # DEST_DIR is about to be rm -rf'd; refuse anything that isn't a real,
  # specific path so a mistyped/empty override can't turn into `rm -rf /bin`.
  [[ "$DEST_DIR" == /* ]] || die "DEST_DIR must be an absolute path: $DEST_DIR"
  [[ "$DEST_DIR" != "/" ]] || die "refusing to install to /"

  preflight_link "$DEST_DIR/bin/devstrap"

  # Existing install is replaced only inside the dedicated devstrap
  # destination; arbitrary user files are never removed.
  if [[ -e "$DEST_DIR/bin" || -e "$DEST_DIR/templates" ]]; then
    printf 'This will remove and replace:\n'
    [[ -e "$DEST_DIR/bin" ]] && printf '  %s\n' "$DEST_DIR/bin"
    [[ -e "$DEST_DIR/templates" ]] && printf '  %s\n' "$DEST_DIR/templates"
    confirm "Continue?"
  fi

  mkdir -p "$DEST_DIR"
  rm -rf "${DEST_DIR:?}/bin" "${DEST_DIR:?}/templates"
  cp -R "$ROOT/bin" "$ROOT/templates" "$DEST_DIR/"

  write_link "$DEST_DIR/bin/devstrap"

  printf 'Installed devstrap runtime to: %s\n' "$DEST_DIR"
  printf 'Command symlink: %s -> %s/bin/devstrap\n' "$LINK" "$DEST_DIR"
  printf 'This copy is independent of %s; re-run install.sh --standalone to update it.\n' "$ROOT"
  printf '\nTo uninstall, delete:\n'
  printf '  %s (command symlink)\n' "$LINK"
  printf '  %s (runtime copy: bin/, templates/)\n' "$DEST_DIR"
else
  preflight_link "$ROOT/bin/devstrap"
  write_link "$ROOT/bin/devstrap"

  printf 'Linked devstrap to this checkout: %s\n' "$ROOT"
  printf 'Command symlink: %s -> %s/bin/devstrap\n' "$LINK" "$ROOT"
  printf 'Templates are read from %s/templates, so edits there apply immediately.\n' "$ROOT"
  printf 'Keep the checkout in place: moving or deleting it breaks the command.\n'

  # Informational only. A previous --standalone install is now unreferenced,
  # but removing files this mode never created is the user's call, not ours.
  if [[ -e "$DEST_DIR/bin/devstrap" ]]; then
    printf '\nNote: a standalone install is still present at %s.\n' "$DEST_DIR"
    printf 'Nothing points at it now; delete it if you do not want the extra copy.\n'
  fi

  printf '\nTo uninstall, delete:\n'
  printf '  %s (command symlink; the checkout is left alone)\n' "$LINK"
fi

printf '\nEnsure %s is on PATH. See docs/NIXOS_INSTALL.md.\n' "$BIN_DIR"
