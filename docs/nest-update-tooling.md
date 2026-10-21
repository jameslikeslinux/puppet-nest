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
The lifecycle package selected below supersedes this first checked-reset slice.
Release-aware fleet modes remain later integration work, not commands to infer
from the audit's proposed examples.

## Persisted preparation source contract

CLI MR !9 merged source `f13f50936671f8e04d0c5b25da0f9ec6aa2f42a1`
as `6c3e7f3dc7692d5d1c9713c8f35e2e43bb2843ed`. Required pipeline 11029
passed. Its complete library aggregate SHA256 is
`2ef34733c3a40349a3c75353677fe153e5a22ab29cba88e788b0534100595587`
over 26 library files. This preparation slice is included in the lifecycle
package below; a merged source contract is not installed support.

After immutable packaging and provisioning, the source supports preparation
with `--transaction ID --release sha256:DIGEST --root-generation PATH`, exact
`--resume-transaction ID`, and read-only `nest reset status ID --format=json`
and `nest reset report ID --format=json`. Consult CLI
`docs/reset-transactions.md` for the schema and complete validation contract.
Only interrupted root sync is replayable after identity/mount checks; ambiguous
backup, mount, kernel, unmount or activation stops for inspection. Prepared is
not booted, accepted, or finalized. These are not authorization to execute reset.

Before transaction mode can be used, `/var/lib/nest/updates` must be an exact
root-owned mode-0700 mount of a dedicated writable host-local ZFS filesystem
outside ROOT. Its pool must carry `org.nest:host-id` matching the stable machine
ID. Both A and B must mount that same dataset after their private `/var` and
before update clients. Do not provision per-BE state or use a network fallback.
The reset filter excludes the entire state subtree from both copy and deletion,
including legacy reset. That protection alone does not provision shared storage.

The source currently requires one canonical local read-only versioned ZFS root
generation, with no descendants/submounts and `org.nest:release=sha256:DIGEST`.
The publisher must preserve its identity and never make it writable or recycle
it. Mutable `/nest/hosts/HOST` and network-host aliases are refused; there is no
automatic source transfer or fallback. Generation publication, capacity admission,
shared mount provisioning, package installation, and actual A/B boot continuity
are still integration work, not proven by this source merge. Avoid blanket raw
replication or extra capacity rehearsals to satisfy the source contract.

Report export is sanitized stdout, not a remotely usable artifact path. Bolt
must explicitly copy it to the supervisor filesystem, atomically publish it,
reopen it, validate schema/ID/release/phase rows, and retain it before completion.
No historical receipt is recreated by replaying production. Preparation alone
does not prove boot, acceptance or finalize; do not infer those transitions from
`success: true` on a preparation report.

## Lifecycle package and compatibility

### Host-local shared transaction state

`nest::update_state` is an explicit host opt-in, initially selected only for
Owl. The default is false, including excluded consoles. The `nest_update_state`
tag delivers the helper and enabled `nest-update-state.service`. Offline host
builds install/enable the unit but never provision storage. On a real host the
oneshot runs after `zfs-mount.service` and the selected root's `/var/lib` mount.
It creates only `PARENT/nest-updates`, where the unique current ZFS root is
`PARENT/ROOT/A` or `PARENT/ROOT/B`, and mounts it at `/var/lib/nest/updates`.
The dataset is outside ROOT, writable, `canmount=noauto`, root-owned mode 0700.
The unit is the explicit mount owner; ordinary `zfs mount -al` cannot race it
ahead of private `/var`. No stop or restart unmounts the state.

The helper binds the root pool and dataset to the stable machine identity using
`org.nest:host-id`. Existing mismatched bindings, alien datasets/mounts, unsafe
ancestors, stacked roots, submounts or populated unmounted state paths refuse
without hiding or moving receipts. It never adopts arbitrary existing datasets,
relaxes quotas/reserves, changes boot selection, unmounts, deletes or replays a
transaction. Its private provisioning lock is separate from the CLI transaction
lock and never unlinked. An interrupted empty owned creation may converge on
retry; unsafe populated or mounted permissions require inspection, not repair.
Root-pool placement asserts host-local storage; it is not an independent proof
of the physical block transport or exclusive pool ownership.

`sudo /usr/local/sbin/nest-update-state --check` reads state without creating
directories or locks. A successful check confirms provisioning, not a prepared
transaction. The CLI still refuses a missing immutable generation. Before the
first A/B exercise, both the accepted root generation and retained rollback
must contain the managed unit/helper and enabled boot ordering, or their
boot-time continuity must be provided through an explicitly reviewed path.
Installing this unit on the running BE alone is not proof of that continuity.
No inactive BE is mounted or modified merely to manufacture test evidence.

Rollback disables future clients/host opt-in but retains the dataset, binding,
receipts and installed mount unit until any unresolved lifecycle is resolved.
Removing the Hiera opt-in deliberately does not destroy or unmount shared state.
Real A/B mount continuity remains a separately authorized canary requirement.

CLI MR !10 merged as `84f95665bc46519fb27d1f670a5d28b0d515321c` after required
exact-head pipeline 11036 passed. Overlay MR !5 packages that merge as
`=app-admin/nest-cli-0.9.0_p20261021-r1::nest`, selected by `nest::base::cli`.
Its complete 28-library-file aggregate SHA256 is
`85ba2dddc1289e3b4ab2fbea1fda628e41491f5a9b88bbea778cd1dde7228d79`.
Required overlay pipeline 11039 and merged-main pipeline 11040 passed. A new
package selection still requires managed installation and installed file-map
readback; CI is not live host acceptance.

This revision includes explicit bound postboot acceptance and safe finalize.
Use its installed `docs/reset-lifecycle.md` contract, not proposed audit flags.
The collector, shared-state mount and immutable generation are prerequisites;
installing the package does not provision them or authorize a reset. A supplied
acceptance document must reflect real collected gates, not operator assertions
invented to move a transaction forward. Finalize retains ambiguous/external
origins and does not claim snapshot retirement or physical reclamation.

Retain `0.9.0_p20261021` as the activation-safe code rollback. Earlier versions
cannot interpret lifecycle receipts: do not downgrade to bypass a failed
transaction, erase state/locks, or replay a legacy reset. The new immutable
revision must not receive the historical exact-version activation patch.

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

## Full Hermes backup publication

The existing `nest::app::hermes::backup` plan accepts `stage_dir` (default
`/var/tmp/nest-hermes-backup`) and `preserve_existing` (default `false`). The
uploaded helper requires `--stage-dir` for capture; direct helper callers must
add it. Prune and legacy-cleanup interfaces are unchanged. A bounded capture
that must retain every existing generation uses `preserve_existing=true`.

Capture and native temporary files live in a private unique local directory.
The helper rejects final-storage staging paths and unknown/network filesystem
types. It verifies full CRC and required shared/profile members locally before
copying verified bytes to a unique hidden final-storage transfer file. SHA256
readback, fsync and no-clobber hard-link publication precede atomic metadata;
the exact receipt is reopened before success or retention. Hidden transfer
files are publication traffic, not working generations. An interruption can
leave a transfer or an archive without metadata: neither is a completed
generation, and the same checkpoint is refused rather than overwritten or
recaptured. Inspect those exact artifacts; do not delete prior good backups.

Hermes MR !86 coordinates native full capture with cron retention/removal
using the actual stores' native/enclosing full-root backup locks. Contended
retention defers until the next save; explicit removal returns failure without
deleting output. This is coordinated live capture, not a simultaneous snapshot
of every mutable file. Existing full-root filters and WAL-safe SQLite semantics
remain native Hermes responsibilities. Publication tests are not proof that
the native fix is installed or that a live backup capture succeeded.

Private ZIPs and JSON metadata stay mode 0600 in the private final directory;
never attach backup payloads or credentials as task evidence. Rollback retains
the previous complete generation and helper. Do not restore live state merely
to validate publication. Old complete metadata without a digest remains
readable; new receipts bind SHA256 as well as byte/member counts.

Hermes MR !87 extends that coordination to process-result retention and native
checkpoint removal. Its deterministic concurrent capture regression failed on
the accepted base; required exact-head pipeline 11106 passed on source
`39748cbe20a9b792d79729f7d79a6eec31f9d4a0`. This closes a distinct observed
process-result deletion path, not just the earlier cron-output retention path.
Genuinely missing selected files still fail capture rather than being omitted.

Owl's managed native source pin includes merge `24f541e4e0a022a76d9e3913968ec59db29cc73d`.
The `hermes_source` tag selects the existing source checkout and exact-pin
verification only: no package reinstall, UI build or service restart. This
source-only delivery is appropriate here because the capture patch changes no
dependencies and the existing install is editable. It is not a substitute for
the normal installer on a new host. Existing gateway/cron processes must still
reload through the normal service lifecycle before their loaded retention code
is covered. Verify those process transitions before the bounded real capture;
do not infer loaded-code identity from a new on-disk checkout alone.

## Durable report export to the supervisor

`nest::host::update_report` reads one existing native transaction and passes its
sanitized JSON stdout to `nest::retain_update_report` on Bolt's `localhost`.
It never prepares, resumes, accepts, finalizes, resets or reboots a host. Supply
the exact expected transaction, release digest and host hostname; the inventory
alias alone is not an accepted hostname assertion. Missing shared state, missing
receipt or failed transport stops collection, not a reason to recreate a cycle.

Create a canonical output directory on persistent supervisor storage first.
With the existing Nest container wrapper, `localhost` is the short-lived Bolt
container: use `/modules/nest/rollout-evidence/ROUND` backed by the caller's
project `rollout-evidence/ROUND` directory. An arbitrary container `/tmp` path is
not durable outside that container. The task intentionally refuses missing or
symlinked directories. This plan does not create an artifact service or infer
that a remote path exists on the notification host.

The retained JSON is schema 1, kind `nest_update_retained_report`, with explicit
`cli_schema` 1 or 2. It projects bounded known host, source, state, identity,
policy and ordered native phase/command-exit fields from the CLI export. Unknown
fields, raw command output, environment, exception text and full acceptance
payloads are not copied. It checks expected host/transaction/release bindings,
pool and current/target tree associations, phase order, completeness and outcome
flags. Missing data or a failed command cannot become a prepared outcome.
The CLI's accepted/finalized flags are labeled `cli_accepted` and
`cli_finalized`; `acceptance_independently_verified` remains false. Retaining
the CLI assertion does not validate collector gate artifacts or prove a reboot.

Each observation has a content-addressed filename, preserving previous pending,
failed and successful reports instead of overwriting the only prior receipt.
Publication writes/fsyncs a unique temporary file, publishes with a no-clobber
hard link, fsyncs the directory, reopens exact bytes and parses the retained
report. Identical concurrent copies are idempotent; conflicting existing bytes
fail without replacement. The returned receipt includes exact path, SHA256,
byte and phase counts, host, transaction, release and readback status. Only this
allowlisted projection is mode 0644; private native receipts remain on the host.

Before completing the enclosing workflow, reopen the corresponding caller-side
path, verify the returned digest and bindings, and retain that real file through
the existing task artifact API. This plan proves the producer-to-supervisor
boundary, not the subsequent notification-host copy or terminal transition.
Do not list an ephemeral container path as a Kanban deliverable. Report retention
has no automatic pruning; retain failed evidence and handle future retention
under release policy. Rollback disables this collection plan without altering
the native host transaction or its retained reports.

## Legacy host update safety floor

The existing `nest::host::update` plan still defaults to `reboot=false`.
Preparation failure now aborts the plan before any reboot or post-reboot Puppet
phase. The expired unconditional `--resume` workaround is removed: a failed or
ambiguous reset is never automatically replayed. In a mixed-result invocation,
even successfully prepared hosts stay unrebooted; inspect their receipts before
continuing. Successful preparation does not grant new reboot authority.

This conservative compatibility floor is not the completed transaction-aware
wave scheduler. Release policy, explicit per-host phase modes, reboot continuity,
failure-domain admission and acceptance/report collection remain integration
work. Do not call the legacy plan to test those proposed interfaces. Its plan
regressions execute the actual Puppet plan with Bolt's mock executor and mock
subplans, never real reset or reboot commands.

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
