# devstrap

Small, explicit project-development bootstrapper. The first templates focus on
Claude/agent isolation in a Dev Container and a minimal Nix dev shell.

## Prerequisites

`devstrap` itself is a small Bash tool, but the generated development
environments rely on a few host-side pieces. Install these before using the
Claude Dev Container workflow:

- **Docker** — the Docker daemon must be running, and your user must be able to
  access it. `docker info` should succeed without `sudo`.
- **Visual Studio Code** — used to open and manage the generated Dev Container.
- **VS Code Dev Containers extension** — extension ID
  `ms-vscode-remote.remote-containers`.
- **Network access for the initial container build** — VS Code/Docker need to
  pull the base image and Dev Container features the first time the container is
  built.

The `claude` container template installs **Claude Code**, **Node.js**, and
**Nix** inside the container. They do not need to be installed on the host for
that workflow.

If you use `--shell nix` and want to run `nix develop` directly on the host,
then the host also needs a Nix installation with flakes enabled. If the project
is opened in the generated Claude Dev Container, Nix is already provided there.

### NixOS baseline

The essential NixOS pieces are the same ones used by `setup_nixos`: Docker is
enabled, the development user can access the Docker daemon, VS Code is
installed, and the Dev Containers extension is enabled. A minimal equivalent is
roughly:

```nix
# NixOS
virtualisation.docker.enable = true;

users.users.myuser.extraGroups = [
  "docker"
];
```

And, when managing VS Code through Home Manager:

```nix
programs.vscode = {
  enable = true;

  profiles.default.extensions = with pkgs.vscode-extensions; [
    ms-vscode-remote.remote-containers
  ];
};
```

After adding a user to the `docker` group, log out and back in (or reboot) so
the new group membership is active. A quick host-side check is:

```bash
docker info
code --version
```

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

## Opening an initialized project in VS Code

After `devstrap` has created the project configuration, open the project folder
in VS Code:

```bash
cd ~/src/example
code .
```

Then open the Command Palette and run:

```text
Dev Containers: Reopen in Container
```

VS Code will build the container on the first run and reopen the same project
with the workspace mounted inside the container. The generated Claude template
uses `/workspace/<project-name>` as the container workspace and runs the VS Code
remote session as the unprivileged `vscode` user.

If the project is not already open in VS Code, you can instead use the Command
Palette command:

```text
Dev Containers: Open Folder in Container...
```

and select the project directory.

On the first build, pulling the base image and features can take a little time.
Once the container opens, the integrated terminal can be used to sanity-check
the environment:

```bash
pwd
whoami
claude --version
nix --version
```

For a generated Nix dev shell, enter it from the container terminal with:

```bash
nix develop
```

If `.devcontainer/` is later changed, use:
`Dev Containers: Rebuild and Reopen in Container` so VS Code rebuilds the
container from the updated configuration.

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
