# TODO

## Devcontainer template hardening

- [ ] Remove `vscode`'s passwordless sudo in `templates/container/claude/Dockerfile`
      (e.g. `rm -f /etc/sudoers.d/vscode /etc/sudoers.d/*-vscode && deluser vscode sudo`).
      The base image grants NOPASSWD sudo by default; that's the actual
      root-of-trust today, since `claude-managed-settings.json`'s
      `Bash(sudo *)` deny rule is a text match on the command string, not an
      OS control (e.g. an absolute path to the sudo binary sidesteps it).
      Without this, a bypass of that one rule undoes every other deny rule,
      including rewriting the managed-settings file itself. Apply the same
      change to the root `.devcontainer/Dockerfile` to keep dogfooding in sync.
- [ ] Add `Write(//etc/**)` to the `deny` list in `claude-managed-settings.json`
      alongside the existing `Edit(//etc/**)`, so creating new files under
      `/etc` via the Write tool is blocked too, not just editing existing ones.

## CI / pre-commit

- [ ] Run these automatically instead of relying on someone remembering to
      run them locally — either a GitHub Actions workflow on push/PR, or a
      pre-commit hook, or both:
      - `bash -n bin/devstrap install.sh` as a cheap syntax-only sanity check
        (does not apply to `tests/devstrap.bats` — bats' `@test { }` syntax
        isn't valid plain bash, only `bats`/`shellcheck` understand it).
      - `shellcheck bin/devstrap install.sh tests/devstrap.bats`
      - `bats tests/devstrap.bats`
      All three only need `nix develop`'s dev shell (`bats`, `shellcheck`), so
      a CI job can just run them inside `nix develop --command bash -c '...'`.
</content>
