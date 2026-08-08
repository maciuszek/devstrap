#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() { echo "test failed: $*" >&2; exit 1; }

# Both components on a clean project.
mkdir "$TMP/both"
"$ROOT/bin/devstrap" --container claude --shell nix --project-dir "$TMP/both" >/dev/null

test -f "$TMP/both/.devcontainer/devcontainer.json"
test -f "$TMP/both/.devcontainer/Dockerfile"
test -f "$TMP/both/.devcontainer/claude-managed-settings.json"
test -f "$TMP/both/.devcontainer/devcontainer-lock.json"
test -f "$TMP/both/flake.nix"
grep -q '"name": "both"' "$TMP/both/.devcontainer/devcontainer.json"
grep -q '/workspace/both' "$TMP/both/.devcontainer/devcontainer.json"

# Container-only must coexist with an existing dev shell.
mkdir "$TMP/container-only"
touch "$TMP/container-only/flake.nix" "$TMP/container-only/flake.lock"
"$ROOT/bin/devstrap" --container claude --project-dir "$TMP/container-only" >/dev/null
test -d "$TMP/container-only/.devcontainer"

# Shell-only must coexist with an existing devcontainer.
mkdir -p "$TMP/shell-only/.devcontainer"
touch "$TMP/shell-only/.devcontainer/existing"
"$ROOT/bin/devstrap" --shell nix --project-dir "$TMP/shell-only" >/dev/null
test -f "$TMP/shell-only/flake.nix"
test -f "$TMP/shell-only/.devcontainer/existing"

# Combined mode is all-or-nothing if the container conflicts.
mkdir -p "$TMP/both-container-conflict/.devcontainer"
if "$ROOT/bin/devstrap" --container claude --shell nix --project-dir "$TMP/both-container-conflict" >/dev/null 2>&1; then
  fail "combined mode should fail on an existing .devcontainer"
fi
test ! -e "$TMP/both-container-conflict/flake.nix" || fail "combined failure created flake.nix"

# Combined mode is all-or-nothing if the shell conflicts.
mkdir "$TMP/both-shell-conflict"
touch "$TMP/both-shell-conflict/flake.lock"
if "$ROOT/bin/devstrap" --container claude --shell nix --project-dir "$TMP/both-shell-conflict" >/dev/null 2>&1; then
  fail "combined mode should fail on an existing flake.lock"
fi
test ! -e "$TMP/both-shell-conflict/.devcontainer" || fail "combined failure created .devcontainer"

# Report all conflicts, grouped by requested component.
mkdir -p "$TMP/all-conflicts/.devcontainer"
touch "$TMP/all-conflicts/flake.nix" "$TMP/all-conflicts/flake.lock"
set +e
output=$("$ROOT/bin/devstrap" --container claude --shell nix --project-dir "$TMP/all-conflicts" 2>&1)
status=$?
set -e
(( status != 0 )) || fail "all-conflicts case unexpectedly succeeded"
grep -q 'dev-container (claude):' <<<"$output" || fail "container conflict heading missing"
grep -q '/.devcontainer already exists' <<<"$output" || fail "container conflict missing"
grep -q 'dev-shell (nix):' <<<"$output" || fail "shell conflict heading missing"
grep -q '/flake.nix already exists' <<<"$output" || fail "flake.nix conflict missing"
grep -q '/flake.lock already exists' <<<"$output" || fail "flake.lock conflict missing"
grep -q 'no files were changed' <<<"$output" || fail "atomic failure message missing"

printf 'tests passed\n'
