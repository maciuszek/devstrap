#!/usr/bin/env bats

setup() {
  ROOT="$(cd -- "$BATS_TEST_DIRNAME/.." && pwd -P)"
  # bats creates and removes BATS_TEST_TMPDIR per test, so nothing here needs
  # its own cleanup. Both installer destinations stay inside it.
  BIN="$BATS_TEST_TMPDIR/bin"
  DEST="$BATS_TEST_TMPDIR/runtime"
}

# Run install.sh against the temp destinations with its prompts answered from a
# here-string, so a test can never block on a prompt or depend on inherited
# stdin. First argument is the answer; the rest are installer flags.
installer() {
  local reply=$1
  shift
  DEST_DIR="$DEST" BIN_DIR="$BIN" "$ROOT/install.sh" "$@" <<<"$reply"
}

@test "link install points the command at the checkout and copies nothing" {
  run installer ""
  [ "$status" -eq 0 ]

  [ -L "$BIN/devstrap" ]
  [ "$(readlink "$BIN/devstrap")" = "$ROOT/bin/devstrap" ]
  [ ! -e "$DEST" ]
  [[ "$output" == *"Linked devstrap to this checkout: $ROOT"* ]]
  [[ "$output" == *"To uninstall, delete:"* ]]
}

@test "linked command resolves templates from the checkout" {
  installer ""
  mkdir "$BATS_TEST_TMPDIR/project"

  run "$BIN/devstrap" --shell bash --project-dir "$BATS_TEST_TMPDIR/project"
  [ "$status" -eq 0 ]
  [ -f "$BATS_TEST_TMPDIR/project/flake.nix" ]
}

@test "re-running the link install neither prompts nor changes the link" {
  installer ""

  # A prompt would consume this "n" and abort; exit 0 proves none was asked.
  # (The prompt string itself never reaches $output: `read -p` writes it only
  # when stdin is a terminal, and these runs are fed from a here-string.)
  run installer n
  [ "$status" -eq 0 ]
  [ "$(readlink "$BIN/devstrap")" = "$ROOT/bin/devstrap" ]
}

@test "standalone install copies the runtime and links there" {
  run installer "" --standalone
  [ "$status" -eq 0 ]

  [ -x "$DEST/bin/devstrap" ]
  [ -d "$DEST/templates" ]
  [ "$(readlink "$BIN/devstrap")" = "$DEST/bin/devstrap" ]
  [[ "$output" == *"To uninstall, delete:"* ]]
  [[ "$output" == *"$DEST (runtime copy: bin/, templates/)"* ]]
}

@test "standalone command works without the checkout on its path" {
  installer "" --standalone
  mkdir "$BATS_TEST_TMPDIR/project"

  run "$DEST/bin/devstrap" --shell nix --project-dir "$BATS_TEST_TMPDIR/project"
  [ "$status" -eq 0 ]
  [ -f "$BATS_TEST_TMPDIR/project/flake.nix" ]
}

@test "switching from link to standalone repoints after confirmation" {
  installer ""

  run installer y --standalone
  [ "$status" -eq 0 ]
  [[ "$output" == *"This will repoint the existing command symlink:"* ]]
  [ "$(readlink "$BIN/devstrap")" = "$DEST/bin/devstrap" ]
}

@test "link install reports a leftover standalone runtime without deleting it" {
  installer "" --standalone

  run installer y
  [ "$status" -eq 0 ]
  [[ "$output" == *"a standalone install is still present at $DEST"* ]]
  [ -x "$DEST/bin/devstrap" ]
  [ -d "$DEST/templates" ]
}

@test "link install onto a clean system reports no leftover runtime" {
  run installer ""
  [ "$status" -eq 0 ]
  [[ "$output" != *"standalone install is still present"* ]]
}

@test "declining the repoint prompt changes nothing" {
  installer ""

  run installer n --standalone
  [ "$status" -ne 0 ]
  [[ "$output" == *"aborted"* ]]
  [ "$(readlink "$BIN/devstrap")" = "$ROOT/bin/devstrap" ]
  [ ! -e "$DEST" ]
}

@test "an existing standalone install is replaced only after confirmation" {
  installer "" --standalone
  touch "$DEST/templates/stale-marker"

  run installer n --standalone
  [ "$status" -ne 0 ]
  [[ "$output" == *"This will remove and replace:"* ]]
  [ -f "$DEST/templates/stale-marker" ]

  run installer y --standalone
  [ "$status" -eq 0 ]
  [ ! -e "$DEST/templates/stale-marker" ]
  [ -d "$DEST/templates/container/claude" ]
}

@test "a directory at the command path fails closed" {
  mkdir -p "$BIN/devstrap"

  run installer ""
  [ "$status" -ne 0 ]
  [[ "$output" == *"refusing to replace directory: $BIN/devstrap"* ]]
  [ ! -e "$BIN/devstrap/devstrap" ]
}

@test "an unrelated file at the command path is replaced only after confirmation" {
  mkdir -p "$BIN"
  printf 'not devstrap\n' >"$BIN/devstrap"

  run installer n
  [ "$status" -ne 0 ]
  [[ "$output" == *"This will replace the existing file:"* ]]
  [ ! -L "$BIN/devstrap" ]
  grep -q "not devstrap" "$BIN/devstrap"

  run installer y
  [ "$status" -eq 0 ]
  [ "$(readlink "$BIN/devstrap")" = "$ROOT/bin/devstrap" ]
}

@test "an incomplete checkout is rejected before linking" {
  partial="$BATS_TEST_TMPDIR/partial"
  mkdir -p "$partial/bin"
  cp "$ROOT/install.sh" "$partial/install.sh"
  cp "$ROOT/bin/devstrap" "$partial/bin/devstrap"

  run env DEST_DIR="$DEST" BIN_DIR="$BIN" "$partial/install.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing templates directory: $partial/templates"* ]]
  [ ! -e "$BIN/devstrap" ]
}

@test "an unknown argument is rejected with usage" {
  run installer "" --dev
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown argument: --dev"* ]]
  [[ "$output" == *"Usage: install.sh"* ]]
  [ ! -e "$BIN/devstrap" ]
}

@test "--help prints usage and installs nothing" {
  run installer "" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: install.sh"* ]]
  [ ! -e "$BIN/devstrap" ]
  [ ! -e "$DEST" ]
}
