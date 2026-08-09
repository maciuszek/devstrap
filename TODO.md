# TODO

devstrap is stable and usable in its intended/default workflow. The items below
cover edge-case bugs, defense-in-depth hardening, documentation, reproducibility,
and portability improvements. Items are ordered by how much risk they actually
remove.

**Destructive surface** (verified 2026-08-09): the repo runs `rm` in two
places — `install.sh:27`, already gated by the confirmation prompt at
`install.sh:19-25`, and `tests/devstrap.bats:9`, on a `mktemp -d` path.
`bin/devstrap` never deletes anything: it validates requested templates and
conflicts up front, then only creates/writes the requested generated files.

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

- [ ] **Resolve and vet `DEST_DIR` before `install.sh` removes anything.**
      Two problems share one root cause: `rm -rf "${DEST_DIR:?}/bin"
      "${DEST_DIR:?}/templates"` (`install.sh:27`) acts on an unnormalized,
      unresolved path.
      - *Symlinked root.* The trailing components resolve *through* a
        symlinked `DEST_DIR`, so the delete lands in the link target.
        Realistic case: someone symlinks `~/.local/share/devstrap` at their
        checkout to develop against it live, runs `./install.sh`, and loses
        `bin/` and `templates/` from the source repo.
      - *The `/` guard is a blocklist with holes.* `install.sh:13` compares
        against the literal string `/`, so `DEST_DIR=//` passes both guards
        and the removal resolves to `/bin` and `/templates`; `DEST_DIR=/usr`
        passes just as easily and targets `/usr/bin`. Both require a
        deliberate override *and* a typed `y` at the prompt, which does
        display the pathological path — so this is a weak guard, not a silent
        destruction path.

      Normalizing early (`cd "$DEST_DIR" && pwd -P` after the `mkdir -p`)
      collapses `//`, resolves the symlink, and makes the prompt honest — it
      currently prints the literal `$DEST_DIR/bin` while `rm -rf` acts on the
      resolved path, so in the symlink case the gate names the install
      directory while something else is deleted. Resolution alone still
      deletes the developer's source repo, so also refuse when the original
      `DEST_DIR` was a symlink. Stronger still, and worth considering
      together: gate removal on recognizing a prior devstrap install (e.g.
      require `$DEST_DIR/bin/devstrap`) rather than on rejecting known-bad
      paths, which turns the guard from a blocklist into an allowlist.

- [ ] **Say what the container does and doesn't protect.** It limits host
      blast radius by bind-mounting only the active project — it does not
      protect that project, which is intentionally writable by the agent. The
      README should state plainly: agent mistakes can still modify or delete
      files in the repo; Git and backups are the real protection for its
      contents; the deny rules are text-pattern defense-in-depth, not a
      filesystem boundary; and a devcontainer is not equivalent to a VM-level
      boundary.

      Be concrete about the last point, because the deny list reads stronger
      than it is. It blocks `rm -rf`, `find -delete`, and `rsync --delete` as
      command-string patterns. It does not block `mv`, `truncate`, `git
      checkout .`, `git restore`, plain `rm` without those flags, or any
      interpreter (`python`, `node`, `perl`) opening a file for writing. An
      agent that damages the repo will not do it through a string that
      matches those patterns, so the rules narrow the accident surface rather
      than bounding it.

- [ ] **Determine what host credentials reach the Claude container.** VS Code
      Dev Containers can forward an SSH agent and inject Git credential
      helpers with no `~/.ssh` mount involved. This matters because the deny
      list explicitly blocks `git push`: if host credentials are reachable,
      that text-pattern rule is the only thing between the agent and
      publishing under the user's identity. Establish what's actually
      available, decide whether to disable or keep it, and record the answer
      in the README so the container's reach is documented rather than
      assumed.

- [ ] **Audit the security implications of persisted Claude state.** The new
      per-project `~/.claude` volume intentionally survives rebuilds and is
      writable by the container user. Verify which persisted user settings,
      hooks, MCP configuration, trust state, and other files can influence a
      later Claude session; confirm the managed `/etc/claude-code` policy still
      has the precedence we rely on; and document an explicit way to inspect
      or reset the project volume. A normal container rebuild should not be
      described as a clean-state reset anymore.

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
      unnormalized `DEST_DIR` (`//`, a trailing slash) resolved before any
      removal, unexpected `~/bin/devstrap`, and no mutation on failure. Keep the
      `DEST_DIR`/`BIN_DIR` env overrides — they're what lets a test point the
      installer at a temp directory instead of a real `$HOME`.

- [ ] **Validate `PROJECT_NAME`.** `basename "$PROJECT_DIR"` is substituted
      into `devcontainer.json` by `sed`. The current escaping is correct for
      `sed` but isn't JSON escaping, so a `"` in the directory name yields
      invalid JSON silently, and a newline can make `sed` fail after generation
      has already started — leaving a partial `.devcontainer/` and breaking the
      all-or-nothing guarantee `--help` advertises. Validate against something
      like `[A-Za-z0-9._-]+` in the existing pre-write validation phase so
      failure precedes any write. Needs a deliberately odd directory name to
      trigger; correctness more than safety.

- [ ] **Validate installer source inputs before replacing an existing install.**
      `install.sh` currently removes the installed `bin/` and `templates/`
      before copying their replacements. Check that the source checkout has
      the expected runtime/template directories and entrypoint before the
      confirmation/removal phase, so a partial or stale checkout cannot remove
      a working install and then fail during `cp`. This is primarily
      availability/robustness, not arbitrary host-data loss.

- [ ] **Verify fresh Claude-volume ownership and persistence in a real built
      container.** On a brand-new project/volume, confirm `vscode` can write
      `$CLAUDE_CONFIG_DIR`, authenticate, create state, rebuild, and see the
      same state afterwards. Only add Dockerfile ownership setup if this test
      demonstrates it is actually needed; the named-volume pattern itself
      follows Anthropic's documented/reference devcontainer approach.

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
