# Installing devstrap on NixOS

`install.sh` installs the runtime under `~/.local/share/devstrap` and creates:

```text
~/bin/devstrap -> ~/.local/share/devstrap/bin/devstrap
```

## Install / update

From the devstrap repository:

```bash
./install.sh
```

Re-running the command updates the installed `bin/` and `templates/` from the
current checkout.

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

## Development installation

If you want the installed command to immediately follow edits in your clone,
you can skip `install.sh` and link the checkout directly:

```bash
mkdir -p ~/bin
ln -s "$PWD/bin/devstrap" ~/bin/devstrap
```

That mode still requires the adjacent `templates/` directory, so the command
must remain inside the devstrap checkout. The normal installer is less fragile
because it installs both the executable and templates together.
