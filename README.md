# devstrap

Small, explicit project-development bootstrapper. The first templates focus on
Claude/agent isolation in a Dev Container and a minimal Nix dev shell.

## Usage

```bash
devstrap --container claude --shell nix
```

Or select either component independently:

```bash
devstrap --container claude
devstrap --shell nix
```

By default the current directory is the target. You can also use:

```bash
devstrap --container claude --project-dir ~/src/example
```

`devstrap` validates every requested component before writing anything. It refuses to merge with an existing `.devcontainer/`, or with an existing `flake.nix` / `flake.lock` when the Nix dev shell is requested. Conflicts are grouped by component and all detected conflicts are listed.
There is intentionally no `--force` option in the initial version.

## Templates

### `--container claude`

Creates `.devcontainer/` with:

- Claude Code installed as a Dev Container feature.
- Nix and Node Dev Container features.
- A root-owned, read-only Claude managed policy.
- Denials for privilege escalation, common destructive filesystem/disk
  commands, destructive Git operations, and edits under `/etc`.
- A workspace bind mount exposing only the selected repository.

The template is generalized from the devcontainer used by `setup_nixos`.
Project-specific NixOS installer restrictions are intentionally not part of the
generic policy.

### `--shell nix`

Creates a minimal `flake.nix` with an `x86_64-linux` development shell based on
NixOS 26.05 nixpkgs. It starts with `git` and `shellcheck`; projects are expected
to customize their own tool list.

After generation:

```bash
nix develop
```

## Install

The default installer makes the command available as `~/bin/devstrap` while
keeping its templates under `~/.local/share/devstrap`:

```bash
./install.sh
```

See [`docs/NIXOS_INSTALL.md`](docs/NIXOS_INSTALL.md) for declarative PATH setup.

## Dogfooding

This repository itself contains `.devcontainer/` and `flake.nix`, so development
of devstrap can use the same Claude-isolated container + Nix-shell model that it
generates for other projects.

## Scope

The initial version deliberately stays small:

- one container template: `claude`
- one dev-shell template: `nix`
- explicit flags
- no overwrite/merge behavior

Additional templates should be added when a real project needs them rather than
pre-building a large framework.
