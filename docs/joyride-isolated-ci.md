# Joyride project execution boundary

Joyride is a personal application in `joy/joyride` (project 83), not a Nest
application release pipeline. Nest owns only this runner's host configuration
and managed credential selection. The former signing/supervisor framework is
withdrawn; this runner is ordinary application CI, not evidence custody.

## Managed installation

`nest::service::joyride_ci` installs a separate `joyride-ci` system account,
locked password, no login shell or supplementary groups, home mode 0700 and a
rootless Podman API. Owl selects the class and adds the account to
`nest::rootless_users`. The primary Nest user's existing subordinate range is
preserved; the additional identity gets the next disjoint range. Neither the
operator's engine nor its storage is shared.

The rootless API runs in a dedicated system service with delegated cgroups,
private temporary storage, hidden home directories and a read-only host system
outside its own state/runtime paths. Administrative credential directories, existing runner
state, custody, and the rootful/operator sockets are explicitly inaccessible in
the engine's mount namespace, even when a directory is otherwise world-readable.
It requires setuid newuidmap/newgidmap for subordinate mappings;
NoNewPrivileges is intentionally not used on that service.
Netavark 1.17.1 selects `systemd-run --user` when `/run/systemd/system`
exists, even though this system service has no user manager. Present an empty,
read-only `/run/systemd` inside the engine's mount namespace so aardvark runs
directly under the service, binding back only `/run/systemd/resolve` read-only
for the host resolver. Do not
expose a user bus or remove existing administrative path denials to fix DNS.
The rootless API is full authority as this unprivileged identity, not a
read-only socket. This is not a claim of VM-level or hostile-kernel isolation.

A separate rootful runner manager uses only this rootless API for execution.
Its configuration and authentication token live under root-only
`/etc/joyride-ci`, outside the engine user's home, and are mounted only into the
manager. The manager has no host-root Podman socket. Jobs get their own engine's
socket and read-only QEMU binaries for multiarchitecture builds, not the
manager's token/configuration, Bolt, eyaml, Puppet credentials, SSH keys,
operator home, kubeconfig or evidence custody state. The engine's filesystem
view also hides host home directories. No application image is produced here.

The encrypted runner authentication token is selected only inside the installed
class from `private/joyride/ci-runner.yaml`, as Sensitive[String]. Logs and file
diffs must never contain it. Configuration changes are root-owned and require
managed Puppet follow-through. Engine restart propagates to its manager; new
jobs must not be admitted while validating or changing the boundary.

## Cutover gates

Runner 127 is project-only, locked to project 83, tagged `joyride-ci`, untagged
jobs disabled and initially paused. Installation alone does not isolate the
application while broad instance/group runners remain enabled for project 83.

Before accepting the application CI cutover:

1. Verify exact-head/main infrastructure CI and managed host convergence.
2. Verify rootless account, disjoint subordinate mappings, actual engine UID,
   root-only manager token and absence of administrative mounts.
3. Run actual positive build/publish and negative authority canaries on runner
   127, including engine-level attempts to bind denied host paths. Do not read
   credential values to demonstrate denial.
4. Move application job tags/canaries in the existing personal application
   repository lane, preserving all supplied frontend bytes and release gates.
5. Disable shared and group runners for project 83, read back that state, prove
   actual build/release/preview jobs use runner 127, and verify Luna's narrow
   TEST deployment continuity. Leave Nest runners 125/126 unchanged.
6. Preserve ordinary TEST preview/status/rollback operations. Do not reinstall
   the withdrawn signing/supervisor framework. Production membership remains gated.

A paused runner, a matching tag, nonprivileged executor flag, container file
mode or synthetic token-verification manager entry is not execution proof.
Retain working application and rollback credentials; remove obsolete signing
credentials only after exact consumer checks through managed-secret workflows.

## Rollback

Pause runner 127 and let active work finish before stopping its manager/engine.
Keep its encrypted identity and storage for diagnosis. Do not restore broad
application CI authority as an automatic fallback; diagnose the failed job and
use a separately reviewed application execution rollback if necessary. Existing
informational and TEST artifacts need not be rolled out for a runner change.
