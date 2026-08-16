# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`devstrap` is a small Bash CLI that scaffolds development environment files
(a Claude-isolated Dev Container, a minimal Nix dev shell) into a target
project directory. It is a generator/installer, not an application — the
"product" is the set of files it writes into other repositories.

## Commands

Run the test suite (`bats`, available via `flake.nix`'s dev shell):

```bash
nix develop   # enters a shell with bats, shellcheck, unzip, zip
bats tests/
```

Two suites, split by the script under test — add new scenarios as `@test`
blocks in the matching one:

- `tests/devstrap.bats` — exercises `bin/devstrap` end-to-end, asserting on
  created files and conflict-detection behavior. Each `@test` gets its own
  `mktemp -d` project directory via `setup()`/`teardown()`.
- `tests/install.bats` — exercises `install.sh` end-to-end in both modes, with
  `DEST_DIR`/`BIN_DIR` pointed inside bats' per-test `BATS_TEST_TMPDIR` (so no
  cleanup of its own) and the installer's prompts answered from a here-string
  via the `installer` helper. Real `$HOME` is never touched.

Lint shell scripts with `shellcheck` (it understands `.bats` syntax natively
since v0.7.0, no preprocessing needed):

```bash
shellcheck bin/devstrap install.sh tests/*.bats
```

Try the CLI locally without installing:

```bash
bin/devstrap --container claude --shell nix --project-dir /tmp/some-dir
```

Install it onto PATH:

```bash
./install.sh               # links ~/bin/devstrap at this checkout (default)
./install.sh --standalone  # copies bin/ and templates/ to ~/.local/share/devstrap instead
```

## Architecture

- **`bin/devstrap`** — the entire CLI logic in one script. Flow: parse flags →
  resolve the real script location (following symlinks, since the installed
  binary is a symlink into either a checkout or `~/.local/share/devstrap`) →
  validate requested template inputs and component conflicts *before* writing
  anything → write files.
  There is no `--force`; conflicts abort with a grouped report and zero
  filesystem changes (all-or-nothing across both components).
- **`templates/`** — the source of truth for generated file content, mirrored
  by category:
  - `templates/container/claude/` — `Dockerfile`, `claude-managed-settings.json`,
    `devcontainer-lock.json`, `devcontainer.json` (contains `__PROJECT_NAME__`
    placeholders substituted via `sed` at generation time), and
    `claude-md-safety-boundaries.md`, a generic project-level guidance block
    printed after Claude-container generation for the user to review; it is not
    copied into the target repository. It intentionally overlaps the managed
    deny policy while remaining broader advisory guidance.
  - `templates/shell/<name>/flake.nix` (currently `nix`, `bash`) — copied
    verbatim per the chosen `--shell` name, no substitution. `nix` is a
    generic starter (`nixfmt`, `shellcheck`); `bash` is curated for
    bash-script-heavy projects (`shellcheck`, `bats`).
- **`install.sh`** — two modes, both ending in the same `~/bin/devstrap`
  symlink and both requiring a complete checkout (`bin/devstrap` executable,
  `templates/` present), checked before anything is written:
  - default (`--link`) — symlinks `~/bin/devstrap` at *this checkout's*
    `bin/devstrap`. Nothing is copied or removed, and template edits are live,
    so this is the development install and the documented default. The
    checkout becomes load-bearing. If a `--standalone` runtime is still
    present, it reports it as now-unused and leaves it in place.
  - `--standalone` — the previous behavior: copies `bin/` and `templates/`
    into `~/.local/share/devstrap` and links there, so the install survives the
    checkout being moved or deleted, at the cost of needing a re-run to pick up
    changes. Refuses a non-absolute or `/` `DEST_DIR` before it ever runs `rm
    -rf`, and prompts for confirmation before replacing an existing install.

  `preflight_link` gates the symlink for both modes and `write_link` is its
  sole writer: it fails closed on a real directory at that path and prompts
  before repointing an existing link or replacing a file. The gate runs before
  the mode's first filesystem change, so declining any prompt leaves both the
  symlink and any existing install untouched. This repo's own `bin/devstrap`
  resolves symlinks precisely so both layouts work (runtime and templates must
  stay siblings).
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
- Claude state is kept in a per-project Docker named volume mounted at
  `/home/vscode/.claude`; `CLAUDE_CONFIG_DIR` points to the same location so
  authentication and `.claude.json` state survive rebuilds along with settings,
  session history, and auto-memory. This state is deliberately not written into
  the repository.
- VS Code is configured with `claudeCode.preferredLocation = "panel"`.

The deny rules above are Claude Code's own text-pattern permission checks,
not an OS-level control — see `TODO.md` for known, not-yet-applied hardening
(e.g. the base image's default passwordless `sudo` for `vscode` is the actual
root-of-trust today, since it can be reached by paths the `Bash(sudo *)`
pattern doesn't match). The container's bind-mount isolation (only the one
repo is exposed, no docker socket) is the primary host-filesystem isolation
boundary; the deny rules are a defense-in-depth layer on top of it, not a
substitute for it.

Any change to a template must stay in sync with the assertions in
`tests/devstrap.bats` (e.g. the `"name"` and workspace path substitution
checks, the exact list of files created per component).

## Conventions

- Bash scripts use `set -euo pipefail` and `readonly`-style resolved paths;
  follow this in any new script.
- Keep the tool intentionally minimal: one container template (`claude`), two
  shell templates (`nix`, `bash`), explicit flags, no merge/overwrite
  behavior. New templates should be added only when a real consuming project
  needs them, not speculatively.
