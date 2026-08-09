## Safety boundaries

These hold regardless of execution mode — they don't go away if advisory-only is later relaxed.

- Inspect the repository and relevant files before editing.
- Keep every change narrowly scoped. Do not refactor unrelated code.
- Do not run `sudo` or `su`.
- Do not modify disks, partitions, mounts, USB devices, `/etc`, or files outside this repository.
- Do not run `nixos-rebuild`, install NixOS, or flash any device.
- Do not run destructive cleanup commands such as `rm -rf`, `find -delete`, `git clean`, or `rsync --delete`.
- Do not commit, push, force-push, rebase, reset, or otherwise rewrite Git history.
- Do not expose secrets or place secret values in the Nix store.
- Never access or modify Secure Boot keys, SSH keys, cloud credentials, KeePass files, or other credentials.
- Preserve existing behaviour unless the task explicitly requires changing it.
- Treat the mounted repository as the only writable project scope.
