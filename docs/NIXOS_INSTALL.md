# Installing devstrap on NixOS

## NixOS baseline

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

`install.sh` puts the command at `~/bin/devstrap` in both of its modes; they
differ in what that symlink points at.

## Install / update

From the devstrap repository:

```bash
./install.sh
```

The default (`--link`) points the command straight at the checkout:

```text
~/bin/devstrap -> <checkout>/bin/devstrap
```

`devstrap` resolves the symlink before looking for its templates, so it reads
them from the checkout's `templates/` directory. Edits to the checkout — new
templates included — apply on the next run with no reinstall, so this mode only
needs to be run once. In exchange, the checkout has to stay where it is:
moving or deleting it breaks the command.

The alternative copies the runtime out of the checkout instead:

```bash
./install.sh --standalone
```

```text
~/bin/devstrap -> ~/.local/share/devstrap/bin/devstrap
```

That install keeps working if the checkout goes away, but it's a snapshot:
re-run `./install.sh --standalone` to pick up any later change. Re-running
replaces the installed `bin/` and `templates/`, and lists what it's about to
remove and asks for confirmation first.

Either mode asks before repointing an existing `~/bin/devstrap`, so switching
between them is a matter of running the other command and confirming. Switching
to the default leaves the copied runtime under `~/.local/share/devstrap` in
place — the installer points out that it is now unused, but never deletes it.
`DEST_DIR` and `BIN_DIR` override the runtime and command directories.

Then verify:

```bash
~/bin/devstrap --help
```

## Put `~/bin` on PATH declaratively

### Home Manager (recommended if your user environment is managed there)

Add this to the relevant Home Manager module:

```nix
home.sessionPath = [
  "$HOME/bin"
];
```

Then apply your normal Home Manager / NixOS rebuild workflow and start a new
login shell. Verify with:

```bash
command -v devstrap
```

### NixOS user shell initialization

If PATH is managed in your shell configuration instead, add `~/bin` there.
For example with Bash via Home Manager:

```nix
programs.bash = {
  enable = true;
  bashrcExtra = ''
    export PATH="$HOME/bin:$PATH"
  '';
};
```

Prefer `home.sessionPath` when available because it expresses PATH as data
rather than embedding shell-specific initialization.
