#!/usr/bin/env bats

setup() {
  ROOT="$(cd -- "$BATS_TEST_DIRNAME/.." && pwd -P)"
  TMP="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMP"
}

@test "both components on a clean project" {
  mkdir "$TMP/both"
  run "$ROOT/bin/devstrap" --container claude --shell nix --project-dir "$TMP/both"
  [ "$status" -eq 0 ]

  [ -f "$TMP/both/.devcontainer/devcontainer.json" ]
  [ -f "$TMP/both/.devcontainer/Dockerfile" ]
  [ -f "$TMP/both/.devcontainer/claude-managed-settings.json" ]
  [ -f "$TMP/both/.devcontainer/devcontainer-lock.json" ]
  [ -f "$TMP/both/flake.nix" ]

  grep -q '"name": "both"' "$TMP/both/.devcontainer/devcontainer.json"
  grep -q '/workspace/both' "$TMP/both/.devcontainer/devcontainer.json"
  grep -Fq 'source=claude-code-config-${devcontainerId},target=/home/vscode/.claude,type=volume' "$TMP/both/.devcontainer/devcontainer.json"
  grep -q '"CLAUDE_CONFIG_DIR": "/home/vscode/.claude"' "$TMP/both/.devcontainer/devcontainer.json"
  grep -q '"claudeCode.preferredLocation": "panel"' "$TMP/both/.devcontainer/devcontainer.json"
  [[ "$output" == *"Recommended: add the following section to the project CLAUDE.md:"* ]]
  [[ "$output" == *"## Safety boundaries"* ]]
}

@test "bash shell template creates a shellcheck/bats flake" {
  mkdir "$TMP/bash-shell"
  run "$ROOT/bin/devstrap" --shell bash --project-dir "$TMP/bash-shell"
  [ "$status" -eq 0 ]
  [ -f "$TMP/bash-shell/flake.nix" ]
  grep -q "shellcheck" "$TMP/bash-shell/flake.nix"
  grep -q "bats" "$TMP/bash-shell/flake.nix"
}

@test "unknown shell template is rejected" {
  mkdir "$TMP/project"
  run "$ROOT/bin/devstrap" --shell rust --project-dir "$TMP/project"
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown shell template: rust"* ]]
  [ ! -e "$TMP/project/flake.nix" ]
}

@test "container-only must coexist with an existing dev shell" {
  mkdir "$TMP/container-only"
  touch "$TMP/container-only/flake.nix" "$TMP/container-only/flake.lock"
  run "$ROOT/bin/devstrap" --container claude --project-dir "$TMP/container-only"
  [ "$status" -eq 0 ]
  [ -d "$TMP/container-only/.devcontainer" ]
}

@test "shell-only must coexist with an existing devcontainer" {
  mkdir -p "$TMP/shell-only/.devcontainer"
  touch "$TMP/shell-only/.devcontainer/existing"
  run "$ROOT/bin/devstrap" --shell nix --project-dir "$TMP/shell-only"
  [ "$status" -eq 0 ]
  [ -f "$TMP/shell-only/flake.nix" ]
  [ -f "$TMP/shell-only/.devcontainer/existing" ]
}

@test "combined mode is all-or-nothing if the container conflicts" {
  mkdir -p "$TMP/project/.devcontainer"
  run "$ROOT/bin/devstrap" --container claude --shell nix --project-dir "$TMP/project"
  [ "$status" -ne 0 ]
  [ ! -e "$TMP/project/flake.nix" ]
}

@test "combined mode is all-or-nothing if the shell conflicts" {
  mkdir "$TMP/project"
  touch "$TMP/project/flake.lock"
  run "$ROOT/bin/devstrap" --container claude --shell nix --project-dir "$TMP/project"
  [ "$status" -ne 0 ]
  [ ! -e "$TMP/project/.devcontainer" ]
}

@test "reports all conflicts grouped by requested component" {
  mkdir -p "$TMP/project/.devcontainer"
  touch "$TMP/project/flake.nix" "$TMP/project/flake.lock"
  run "$ROOT/bin/devstrap" --container claude --shell nix --project-dir "$TMP/project"
  [ "$status" -ne 0 ]

  [[ "$output" == *"dev-container (claude):"* ]]
  [[ "$output" == *"/.devcontainer already exists"* ]]
  [[ "$output" == *"dev-shell (nix):"* ]]
  [[ "$output" == *"/flake.nix already exists"* ]]
  [[ "$output" == *"/flake.lock already exists"* ]]
  [[ "$output" == *"no files were changed"* ]]
}
