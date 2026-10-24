# Bounded postboot identity observation

`nest::host::update_boot_health` observes one host through the existing Bolt
inventory and root escalation. It never resets, mounts, changes boot selection,
reboots, applies a catalog, records transaction acceptance or finalizes a cycle.
The task's command allowlist is `zpool list`, `zpool get` for `bootfs` and
`zfs get` for `guid,mounted`; it also reads kernel boot/mount information and
hostname.

## Inputs and invocation

Pass `target` and an `expectations` hash, preferably through Bolt's normal JSON
parameter file. The exact hash keys are:

- `hostname`: expected kernel hostname, not an inferred inventory alias.
- `kernel`: exact reviewed release policy value, including qualified exceptions.
- `previous_boot_id`: boot ID retained before the authorized reboot.
- `current`: expected prepared target dataset, ending in `/ROOT/A` or `/ROOT/B`.
- `current_guid` and `var_guid`: exact prepared target and target `/var` GUIDs.
- `pool_guid`: exact retained root-pool GUID.

All values are strings. Derive the expected identities from the actual native
preparation receipt and reviewed release policy. Do not sample the current host
and relabel those samples as an independently expected boot outcome. Missing
preparation evidence is not permission to recreate or reboot a transaction.

Run the existing plan with the parameter file:

```sh
bolt plan run nest::host::update_boot_health --params @boot-observation.json
```

Do not run `nest::host::update` merely to obtain these observations. Before
remote use, verify ordinary inventory-backed `joy` transport as documented in
`nest-bolt-worker-transport.md`; there is no direct/root SSH fallback.

## Output and safety boundary

Output is schema 1, kind `nest_update_boot_health`. It contains the observed
hostname, kernel and boot ID, plus explicit `hostname`, `kernel`, `reboot`,
`mounts` and `storage` checks. `acceptance_recorded` is always false. A successful
Bolt task transport can return `result: fail`; callers must inspect the returned
checks rather than equating process success with health.

A passing observation requires the expected hostname and exact kernel, a boot
ID different from the retained preboot ID, exactly one read-write local ZFS root
and its own read-write `/var`, exact current/var/pool GUIDs, `bootfs` equal to
current, and every imported pool reporting `ONLINE`. Kernel mountinfo includes
shadowed mounts: duplicate roots or `/var` entries refuse rather than accepting
the visible top. Private ZFS mounts under `/var` belonging to a ROOT tree must
belong to the expected current tree at their canonical paths; wrong-BE or
stacked private children refuse. Ordinary shared mounts outside ROOT are not
reclassified as private BE data.

Mount topology and storage identities are independently reacquired after the
complete first acquisition. Hostname, kernel and boot ID are checked again at
the end. Missing commands, malformed/incomplete inventories, changed identities,
wrong next boot, unmounted/wrong-GUID datasets or non-online pools cannot yield
a passing check. Unavailable checks include only fixed reason codes, not raw
command output, environment or exception text. Failure never clears a unit,
changes a quota, deletes rollback or repairs a host.

Commands have a five-second timeout within a thirty-second command budget.
Pool inventory is bounded to 128 entries; mount inventory to one MiB and 16384
rows. This is a bounded observation, not an atomic storage snapshot or a promise
that state cannot change after the task returns. An unavailable/failed pool
observation is retained as failure, never an empty healthy set.

## Coverage limits and rollback

This is the boot/kernel/ZFS component of R11, not a full acceptance collector or
an input accepted directly by `nest reset accept`. It does not prove network,
DNS or TLS trust, device/vdev error counters, physical storage independence,
shared transaction-state continuity, all private filesystem child GUIDs, catalog
main apply/convergence, actual user-manager health or hardware/service/physical
UX. Use the separately shipped manager observation for actual user-manager buses.
Later lifecycle integration must retain and bind both observations to the real
transaction and collect the remaining gates before acceptance or finalize.

Tests use disposable in-memory command/mount fixtures and the real task stdin
interface. They never allocate datasets, mount an inactive BE, change bootfs or
reboot a host. Source/CI verification is distinct from installed/live readback;
a separately authorized real boot canary remains required for lifecycle proof.
Rollback stops calling this observation plan. No host state needs undoing.
