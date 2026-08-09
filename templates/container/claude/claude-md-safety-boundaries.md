## Safety boundaries

These project-level instructions apply regardless of the agent's execution or permission mode. They are intentionally broader than the container's managed deny rules.

- Inspect the repository and relevant files before editing.
- Keep every change narrowly scoped. Do not refactor unrelated code.
- Do not run `sudo` or `su`.
- Do not modify disks, partitions, mounts, removable devices, `/etc`, or files outside this repository.
- Do not install or reconfigure the host operating system, and do not flash firmware or devices.
- Do not run destructive cleanup commands such as `rm -rf`, `find -delete`, `git clean`, or `rsync --delete`.
- Do not commit, push, force-push, rebase, reset, or otherwise rewrite Git history.
- Do not expose secrets or place secret values in build artifacts, logs, generated files, or dependency stores.
- Never access or modify credentials, signing keys, password databases, SSH keys, cloud credentials, or other secrets.
- Preserve existing behaviour unless the task explicitly requires changing it.
- Treat the mounted repository as the only writable project scope.
