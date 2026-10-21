# Nest update tooling

This implementation is staged under request ^2045. The completed audit ^2036
is the design input, not a new authorization to reset or reboot hosts. Source
publication, installed tooling, and actual boot acceptance are separate facts.
The implementation matrix retained with the request records those boundaries
for R01–R12. No historical missing rollout receipts are reconstructed here.

## Checked reset CLI source

CLI MR !8 merged reviewed source `d54cdd14f020b596b8e8cf924bc16c547103de45`
into main as `d56b83bbc61b4f43cfd15001add110112a1efd74`. Required pipeline
11001 passed. Its actual supported observation commands are:

```sh
nest version --format=json
nest reset --plan --format=json
```

These commands require the new package, not merely a version string of 0.9.0.
The complete library manifest for this source has aggregate SHA256
`6937c534d1b62b20f3059149e7f064c6c559c3aaab6a0902251576274fa9756a`.
Compare the complete reported file map as well as the aggregate. This is content
identity, not a signature. Overlay MR !4 packages that exact merge as
`=app-admin/nest-cli-0.9.0_p20261021::nest`; `nest::base::cli` selects the exact
version rather than a mutable latest package. Packaging CI exercised a real
Gentoo build and compared all 23 library files. Live installed checks remain
pending until their receipts appear in the implementation matrix.

The `nest_cli_package` tag selects only the CLI package definition and its
ordinary package policy resources. Sync the configured Nest overlay before
applying this tag; do not replace the overlay checkout by hand. Use the existing
inventory-backed Puppet plan, then reopen `nest version --format=json` and
`nest reset --plan --format=json`. No reset execution, mount-service restart,
or reboot is needed to install or observe this package. Keep the previous
activation-safe package/binpkg available; the old 0.9.0 archive alone is not a
safe rollback unless its existing exact-version activation patch is retained.

Human output remains the default. JSON execution output does not make an
executing reset read-only. Legacy `--resume` only skips backup; it is not a
transaction recovery command. `--noop` and `--test` are not safe observation
substitutes. Firmware-only reset now explicitly fails as unimplemented.

The planner records physical pool space separately from dataset and ancestor
quota/accounting. Admission remains explicitly unknown: successful observation
is not permission to reset, proof that promotion fits, or permission to remove
quotas, reserves, or rollback data. Shared `/boot` remains an execution side
effect. Use the CLI's `docs/reset.md` for schema 1 and process/native exit rules.
Transactions, finalize, and release-aware fleet modes are later implementation
slices, not commands to infer from the audit's proposed examples.

## Fail-closed ZFS startup

`nest` manages the existing activation preflight before `zfs mount -al`:

```ini
[Service]
ExecStartPre=/usr/bin/nest beadm activate
```

There is deliberately no `-` prefix. A failed inactive-tree property write or
promotion must prevent the subsequent automatic mount. The existing CLI
activation-safe implementation is the minimum rollback floor. Do not downgrade
to the old unsafe activation ordering or ignore an activation error to make a
boot appear successful. Preserve the previous accepted BE and inspect failure
before selecting recovery action.

The `nest_cli_safety` tag selects the drop-in and daemon reload, alongside the
existing activation-backport delivery. It does not select the ZFS package,
kernel build, service restart, or a mount operation. From a provisioned project
workspace, the managed delivery/check sequence is:

```sh
bolt module install
bolt inventory show owl --detail --format json
bolt command run 'id -un && hostname -f' --targets owl --stream
bolt plan run nest::puppet::deploy
bolt plan run nest::puppet::run targets=owl tags='["nest_cli_safety"]' --stream
bolt command run 'systemctl show zfs-mount.service -p ExecStartPre -p ExecStart -p ActiveState' --targets owl --stream
```

Review the deploy plan and its current source/environment first. Use ordinary
inventory-backed `joy` transport and Bolt escalation; do not replace it with
root SSH or ad-hoc Puppet. Readback must show `ignore_errors=no` for activation
and the unchanged `zfs mount -al` command. An already active mount service need
not restart, and this sequence must not restart it to manufacture boot evidence.
A daemon reload and parsed service readback do not prove a real reboot test.

## Operational authority and rollback

The implementation scope permits ordinary source publication, nondisruptive
managed tooling delivery, read-only installed checks, and one bounded normal
backup capture. It does not approve OS-stage rebuilds or release promotion,
fleet resets/reboots, quota relaxation, destructive storage changes, or restore.

Before the first real reset/reboot or destructive canary, present one exact
reviewed host, scope, impact, and rollback proposal to Joy. Preserve console
exclusions and current kernel-qualified exceptions. A separately authorized
canary must verify actual boot/rollback behavior; fixture tests and a successful
merge cannot close that acceptance gap.

Stop on ambiguous phases or unavailable observations. Do not repeat backup,
reset, reboot, or cleanup merely to regenerate evidence. Retain the previous
activation-safe CLI package and source manifest. Rollback of tooling does not
undo shared boot writes or authorize restoring application data.
