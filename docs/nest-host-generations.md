# Host-local immutable root generations

`nest::host::stage_generation` bridges an existing versioned Stage 3 publication
and the installed CLI's immutable local source contract. It does not build an
OS, promote a release alias, create/mount datasets, prepare an alternate boot
environment, reset, reboot, accept, finalize, restore, prune or change quotas.
The default `check=true` is read-only, including no lock or receipt creation.
This source interface is not release authorization or live lifecycle evidence.

## Managed interfaces

Puppet installs `/usr/libexec/nest/transfer-generation.py` and the existing
Stage 3 aggregate content-identity implementation beside it. The supported
inventory-backed entrypoint is:

```text
bolt plan run nest::host::stage_generation --params @/PATH/params.json
```

The parameter object has `targets`, `policy` and optional `check` (default true).
Exactly one canonical inventory name must equal `policy.hostname`. Recovery
consoles and qualified controller aliases refuse. Ordinary Joy/Bolt transport
and Bolt root escalation are used; there is no root-SSH fallback. The installed
helper also accepts the exact JSON policy as one positional argument, followed
by optional `--check`. All policy fields are public placement/identity/budget
metadata; never put key bytes, passwords or other secrets in arguments.

`check=false` explicitly copies and seals this one generation. It is a storage
write and potentially significant read/copy load; use the reviewed release's
host, placement, capacity and maintenance scope. It is not implicitly called by
`nest::host::update` or by successful CI. In particular, no actual generation
transfer or disruptive canary is authorized by these examples.

## Exact policy schema 1

The object has exactly these keys; extra/duplicate keys refuse:

- `schema`: integer 1; `kind`: `nest_generation_transfer`.
- `hostname`: canonical lowercase host name, at most 63 characters.
- `host_identity_sha256`: lowercase SHA256 of the exact stable machine-id string
  without newline. The observed hostname and digest must match the target.
- `pool_guid`, `destination_guid`: positive decimal strings. The destination,
  shared transaction state and current A/B root must be in this exact pool.
- `build_release`: existing versioned Stage 3 build token, matching
  `[a-z0-9][a-z0-9._-]{0,127}`.
- `source`: exactly `/nest/releases/BUILD/hosts/HOST`, with the selected build
  and host. This publication must already be accessible via a canonical,
  root-trusted read-only NFS/NFS4 or ZFS mount. No child or stacked mount is
  accepted. This helper never mounts an export or uses `/nest/hosts/HOST`.
- `release`: `sha256:` plus the lowercase 64-character runtime release-manifest
  digest. This is distinct from the build token and from the content digest.
- `content_digest`: exact `sha256:` aggregate returned by the existing Stage 3
  root publisher/checker and bound by the reviewed release. The helper reuses
  the same byte/metadata/xattr/hardlink algorithm, not a new hash dialect.
- `destination`: exactly `/var/lib/nest/generations/HEX`, where `HEX` is the
  runtime release digest without `sha256:`.
- `write_budget_bytes`: positive integer; `physical_reserve_bytes`: nonnegative
  integer. Both are bounded by signed 64-bit integer range; booleans/floats
  refuse. Budgets must come from the reviewed release, not this documentation.

A digest supplied in a policy is a trusted-root/release-owner assertion, not a
signature, proof of remote dataset GUID, or independent discovery of the
relationship between a build root and a runtime release. Actual source bytes
must match that asserted content digest. Release assembly/approval must supply
the correct identities; this helper never invents or promotes them.

## Explicit prerequisites and capacity boundary

Before invoking the helper, provide the existing shared `/var/lib/nest/updates`
contract: a root-owned mode-0700 exact writable ZFS mount outside all `ROOT`
trees, on the current root's pool, whose `org.nest:host-id` equals the actual
machine-id. Missing/unsafe state refuses. State must be shared across A/B;
source checks on one boot do not prove the second boot's mount ordering.

The destination must already be an empty exact writable ZFS filesystem with
the selected GUID, positive creation TXG and canonical root-owned ancestors.
It must be outside `ROOT` and separate from the shared-state tree, with no
children, snapshots or origin. It must have `exec=off`, `setuid=off`,
`devices=off`, and `canmount=on`. The four `org.nest:host`, `org.nest:release`,
`org.nest:build-release` and `org.nest:content-digest` properties must be unset.
No parent, filesystem, quota, reserve, boot mount or ownership is provisioned
or repaired by the helper. A populated/reused/partially copied path refuses.
Puppet's reset filter protects the generation mount tree from writing/deletion;
actual A/B mounting and retention still require release integration.

Transfer admission independently checks apparent one-filesystem source size,
native destination `available`, and whole-pool physical free. The write budget
must cover apparent size; logical available must cover the write budget; free
must cover write budget plus physical reserve. Admission is checked again under
the native host transaction lock before copy. These are configured conservative
budgets, not complete allocation bounds or reservations. Metadata, concurrent
writers and native errors can still stop the copy. No rollback deletion,
compression credit, pending freeing, quota relaxation or copying rehearsal is
used to make it fit.

This transfer budget is NOT the CLI's subsequent reset-capacity policy. After
sealing, use the installed native read-only reset planner with the exact sealed
path and a separately reviewed `nest_reset_capacity_policy`. The native r3
accounting contract still refuses all finite affected quotas/refquotas and
reservations. Nothing here relaxes that boundary or makes a reset eligible.

## Checked copy, sealing and failure handling

The helper rechecks exact host/pool/boot/current root, shared-state GUID,
destination GUID/TXG/mount closure and source mount identity. It takes the same
nonblocking `.lock` as native transactions; it never unlinks or breaks a lock.
Read-only checking takes no lock and is therefore an observation, not a lease.

Before copy, it atomically publishes mode-0600
`generation-GUID.started` in the shared state directory with fsync/readback.
Files deliberately do not end in `.json`, so native transaction-ID discovery
does not mistake them for CLI transactions. The no-clobber reservation survives
failure. Copy uses local-path rsync from the mounted publication, preserving
numeric ownership, modes, nanosecond mtime, ACLs, xattrs and hardlinks. There is
no `--delete`, `--inplace`, remote shell, filtering or source modification.

The full source digest is checked before/after copy and the complete destination
digest must match. After pool sync, one checked ZFS set publishes the exact
hostname, runtime release, build token and content digest with `readonly=on`.
Native properties and the actual read-only mount are rechecked, along with the
same GUID/TXG/boot bindings and full sealed digest. Required package, kernel
source and modules paths must resolve inside that root. Only then is
`generation-GUID.complete` atomically published, fsynced and reopened.

The small JSON report binds policy/digest, observed identities and budget
observations. `sealed=true` means this transfer passed, not that reset capacity,
package compatibility, hardware boot, application recovery or acceptance passed.
`reset_authorized` is always false. The Bolt wrapper checks exact returned
policy and read-only/sealed flags; it never retries a failed command.

On any error or interrupted process, retain the filesystem, `.started` and
native state for diagnosis. Property updates, copy and native storage effects
are not atomic with the receipt. Even an empty failed generation cannot be
replayed automatically. A repeat after successful sealing also refuses rather
than toggling writable or recopying. Read the retained `.complete` receipt and
native source status instead. Removing receipts, deleting datasets, renaming a
generation, rolling back storage or restoring live data is not a recovery mode.
Do not supply another GUID/path merely to evade an ambiguous attempt.

Keep the generation immutable and mounted for native preparation/resume and for
the release retention period. Cleanup is not implemented by this producer;
never make it writable or reuse its identity. No live transfer, real ZFS seal,
A/B boot, finite-limit reset admission or fleet acceptance is proven by unit
fixtures. Tests use disposable ordinary directories and fake ZFS observations;
real rsync, hardlinks/xattrs, flock and atomic receipt publication are exercised.
