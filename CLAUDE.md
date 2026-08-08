# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`devstrap` is a small Bash CLI that scaffolds development environment files
(a Claude-isolated Dev Container, a minimal Nix dev shell) into a target
project directory. It is a generator/installer, not an application — the
"product" is the set of files it writes into other repositories.

## Commands

Run the test suite:

```bash
tests/test-devstrap.sh
```

There is no separate test runner/framework — it's a single Bash script that
exercises `bin/devstrap` end-to-end against temp directories (`mktemp -d`) and
asserts on created files and conflict-detection behavior. Add new scenarios by
appending to this script rather than creating a new test file.

Lint shell scripts with `shellcheck` (available via `flake.nix`'s dev shell):

```bash
nix develop   # enters a shell with shellcheck, unzip, zip
shellcheck bin/devstrap install.sh tests/test-devstrap.sh
```

Try the CLI locally without installing:

```bash
bin/devstrap --container claude --shell nix --project-dir /tmp/some-dir
```

Install it onto PATH:

```bash
./install.sh   # copies bin/ and templates/ to ~/.local/share/devstrap, symlinks ~/bin/devstrap
```

## Architecture

- **`bin/devstrap`** — the entire CLI logic in one script. Flow: parse flags →
  resolve the real script location (following symlinks, since the installed
  binary is a symlink into `~/.local/share/devstrap`) → validate every
  requested component for conflicts *before* writing anything → write files.
  There is no `--force`; conflicts abort with a grouped report and zero
  filesystem changes (all-or-nothing across both components).
- **`templates/`** — the source of truth for generated file content, mirrored
  by category:
  - `templates/container/claude/` — `Dockerfile`, `claude-managed-settings.json`,
    `devcontainer-lock.json`, and `devcontainer.json` (contains
    `__PROJECT_NAME__` placeholders substituted via `sed` at generation time,
    since JSON has no native templating).
  - `templates/shell/nix/flake.nix` — copied verbatim, no substitution.
- **`install.sh`** — copies `bin/` and `templates/` into
  `~/.local/share/devstrap` and symlinks `~/bin/devstrap` to the installed
  runtime. This repo's own `bin/devstrap` resolves symlinks precisely so this
  install layout works (runtime and templates must stay siblings).
- **`.devcontainer/`, `flake.nix`** at the repo root — devstrap dogfoods its
  own `claude` container template and `nix` shell template for its own
  development.

### The `claude` container template

Generates a Dev Container that isolates an agent to a single project:
- `workspaceMount`/`workspaceFolder` bind-mount only the target repo, at
  `/workspace/<project-name>`, as the unprivileged `vscode` user — no broader
  host filesystem access.
- `claude-managed-settings.json` is copied into the image as a root-owned,
  `chmod 0444` file at `/etc/claude-code/managed-settings.json`, making it a
  policy Claude Code cannot edit from inside the container. It denies `sudo`/
  `su`, destructive filesystem/disk operations (`rm -rf`, `dd`, `mkfs`, mount/
  unmount, partitioning), destructive Git operations (`commit`, `push`,
  `clean`, `reset --hard`, `rebase`), and edits under `/etc`. When adjusting
  this policy, keep changes generic — project-specific restrictions belong in
  the consuming project, not this template (see README "Scope").
- Node and Nix are installed as Dev Container features alongside the Claude
  Code feature, with `overrideFeatureInstallOrder` ensuring Node installs
  first.

Any change to a template must stay in sync with the assertions in
`tests/test-devstrap.sh` (e.g. the `"name"` and workspace path substitution
checks, the exact list of files created per component).

## Conventions

- Bash scripts use `set -euo pipefail` and `readonly`-style resolved paths;
  follow this in any new script.
- Keep the tool intentionally minimal: one container template (`claude`), one
  shell template (`nix`), explicit flags, no merge/overwrite behavior. New
  templates should be added only when a real consuming project needs them,
  not speculatively.
</content>
