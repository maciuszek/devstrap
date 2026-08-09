# TODO

devstrap is stable and safe to run as-is — nothing below fixes a live bug.
Items are ordered by how much risk they actually remove.

**Destructive surface** (verified 2026-08-09): the repo runs `rm` in two
places — `install.sh:27`, already gated by the confirmation prompt at
`install.sh:19-25`, and `tests/devstrap.bats:9`, on a `mktemp -d` path.
`bin/devstrap` never deletes anything: it conflict-checks every requested
component up front, then only `mkdir`s and `cp`s.

## Worth doing

- [ ] **Remove `vscode`'s passwordless sudo** from
      `templates/container/claude/Dockerfile` and the root
      `.devcontainer/Dockerfile` (e.g. `rm -f /etc/sudoers.d/vscode
      /etc/sudoers.d/*-vscode && deluser vscode sudo`). Highest-value item
      here: the base image grants NOPASSWD sudo, so root is reachable today,
      and `Bash(sudo *)` is a text match on the command string rather than an
      OS control. One bypass of that single rule undoes every other deny
      rule, including rewriting the managed-settings file itself. Verify in
      the built container that `sudo -n true` fails, and that no feature or
      lifecycle hook needs sudo at runtime. Once this lands, fix the
      CLAUDE.md/README wording that calls the managed-settings file something
      Claude "cannot edit" — that only becomes strictly true afterwards.

- [ ] **Reject a symlinked install root in `install.sh`.** `rm -rf
      "${DEST_DIR:?}/bin" "${DEST_DIR:?}/templates"` (`install.sh:27`)
      resolves those trailing components *through* a symlinked `DEST_DIR`, so
      the delete lands in the link target. The existing absolute-path and
      `:?` guards don't cover this. Realistic case: someone symlinks
      `~/.local/share/devstrap` at their checkout to develop against it live,
      runs `./install.sh`, and loses `bin/` and `templates/` from the source
      repo. Reject a symlinked root before anything destructive runs. While
      there, make the existing prompt honest — it prints the literal
      `$DEST_DIR/bin` while `rm -rf` acts on the resolved path, so in exactly
      this scenario the gate names the install directory while something else
      is deleted.

- [ ] **Determine what host credentials reach the Claude container.** VS Code
      Dev Containers can forward an SSH agent and inject Git credential
      helpers with no `~/.ssh` mount involved. This matters because the deny
      list explicitly blocks `git push`: if host credentials are reachable,
      that text-pattern rule is the only thing between the agent and
      publishing under the user's identity. Establish what's actually
      available, decide whether to disable or keep it, and record the answer
      in the README so the container's reach is documented rather than
      assumed.

- [ ] **Run `shellcheck` and `bats` automatically** — GitHub Actions on
      push/PR, a pre-commit hook, or both. Cheapest item in this file, and
      the only one that prevents *future* bugs rather than fixing a known
      one; it catches the class of quoting and path bug the rest of this list
      is about.
      - `bash -n bin/devstrap install.sh` — syntax-only sanity check. Does
        not apply to `tests/devstrap.bats`: bats' `@test { }` syntax isn't
        valid plain bash, only `bats`/`shellcheck` parse it.
      - `shellcheck bin/devstrap install.sh tests/devstrap.bats`
      - `bats tests/devstrap.bats`
      All three need only `nix develop`'s dev shell, so CI can run them
      inside `nix develop --command bash -c '...'`.

- [ ] Add `Write(//etc/**)` to the `deny` list in
      `claude-managed-settings.json` alongside the existing `Edit(//etc/**)`,
      so creating new files under `/etc` is blocked too, not just editing
      existing ones.

## Worth doing when next touching that code

- [ ] **Preflight `~/bin/devstrap` before linking.** `ln -sfn`
      (`install.sh:30`) unlinks an unrelated regular file or symlink at the
      destination; and if the destination is a real directory it silently
      links *inside* it as `~/bin/devstrap/devstrap`, producing a broken
      install. Link when the path is absent or already points at
      `$DEST_DIR/bin/devstrap`; otherwise fail closed. Low impact — that path
      is specific to this tool — but cheap.

- [ ] **Give `install.sh` test coverage**, as part of the two installer items
      above rather than as separate work: clean install, update with
      confirmation, declined prompt, symlinked `DEST_DIR` rejected,
      unexpected `~/bin/devstrap`, and no mutation on failure. Keep the
      `DEST_DIR`/`BIN_DIR` env overrides — they're what lets a test point the
      installer at a temp directory instead of a real `$HOME`.

- [ ] **Validate `PROJECT_NAME`.** `basename "$PROJECT_DIR"`
      (`bin/devstrap:50`) is substituted into `devcontainer.json` by `sed`.
      The escaping at `bin/devstrap:123` is correct for `sed` but isn't JSON
      escaping, so a `"` in the directory name yields invalid JSON silently,
      and a newline makes `sed` fail *after* the `mkdir` and `cp`s at
      `bin/devstrap:118-121` — leaving a half-built `.devcontainer/` and
      breaking the all-or-nothing guarantee `--help` advertises. Validate
      against something like `[A-Za-z0-9._-]+` next to `bin/devstrap:50`, in
      the existing validation phase, so failure precedes any write. Needs a
      deliberately odd directory name to trigger; correctness more than
      safety.

## Documentation

- [ ] **Say what the container does and doesn't protect.** It limits host
      blast radius by bind-mounting only the active project — it does not
      protect that project, which is intentionally writable by the agent. The
      README should state plainly: agent mistakes can still modify or delete
      files in the repo; Git and backups are the real protection for its
      contents; the deny rules are text-pattern defense-in-depth, not a
      filesystem boundary; and a devcontainer is not equivalent to a VM-level
      boundary.

## Minor

- [ ] Pin the devcontainer base image tighter than
      `mcr.microsoft.com/devcontainers/base:ubuntu` (features are already
      locked via `devcontainer-lock.json`) — an explicit Ubuntu tag, or a
      digest if the maintenance cost is worth it. Note the tradeoff against
      picking up base-image security updates.
- [ ] Support `aarch64-linux` in the generated flakes, which hard-code
      `system = "x86_64-linux";`, ideally without duplicating the `devShell`
      per system. Portability, not safety.
- [ ] Replace the manual `mktemp -d` + `rm -rf` in `tests/devstrap.bats` with
      bats' own `BATS_TEST_TMPDIR`, created and cleaned up per test. Safe as
      written; this just removes a destructive line from the repo.
