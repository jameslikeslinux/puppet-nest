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

Linux subtree bind mounts (including Kubernetes volume subpaths) backed by the
current `/var` or a canonically mounted current private child are not new ZFS
datasets at their target paths. They retain their exact backing source and
subtree in the repeated observation. Wrong-BE sources, missing canonical child
mounts, duplicate private targets and read-only private binds still refuse.
Whole-dataset mounts with mount root `/` must retain the canonical dataset/path
relationship; this observer does not waive that rule for whole-dataset binds.

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

## Bound boot and manager collection

`nest::host::update_health` accepts the same single `target` and `expectations`
parameters. It composes the existing boot and actual-manager observation plans,
in this order: boot, managers, boot. The second boot observation must exactly
match the first, including the observed mount/storage checks. Both must have
the expected hostname and a well-formed boot ID; the manager observation must
carry that same host and boot ID. Schema/kind substitutions or any component
claiming transaction acceptance refuse the binding. Task or transport errors
fail the plan instead of manufacturing empty healthy inventories.

```sh
bolt plan run nest::host::update_health --params @boot-observation.json
```

Output is schema 1, kind `nest_update_health`, containing `boot_before`,
`managers`, `boot_after`, `observations_bound`, `result` and
`acceptance_recorded: false`. A passing result requires stable bound identities
and passing results from both existing collectors. A bound observation can
still fail: missing user buses, unexplained or retained historical failures,
wrong kernel/BE or an unchanged boot ID stay failed. The full manager result
is retained without clearing units, changing failure explanations or converting
unavailable checks to zero. Callers must inspect `result`, not the Bolt exit.

Collection is deliberately single-host and bounded by the component command
budgets: two boot observations and one manager inventory, not a fleet scan or
continuous observer. A changing Kubernetes bind-mount inventory can reject
binding even when each individual observation passed. This conservative result
is not permission to reset/reboot or to keep retrying until a green sample.
Acquisition is not an atomic snapshot, and state can change after it returns.

This integration is not `nest reset accept` evidence. Without explicit endpoint
policy it does not collect network/name-resolution/trust. It never collects
main catalog apply/convergence, service/hardware/physical UX,
transaction/shared-state continuity or policy-owned historical dispositions.
The remaining lifecycle collector must bind those gates to real preparation
and release receipts and retain the resulting report before acceptance.
Rollback stops calling the composed plan; no host state was changed.

## Bounded client network and trust observation

`nest::host::update_network_health` takes one `target` and an `endpoints` array
of one to four reviewed nonsecret HTTPS endpoints. Each endpoint has exactly:

- `hostname`: a lowercase dotted DNS name, without a port or IP literal.
- `addresses`: one to eight unique canonical unicast IP addresses. The complete
  system-resolved address set must match, not merely contain one expected IP.
- `path`: an absolute path without query, fragment, credentials or `..` segments.
- `status`: the exact expected successful HTTP status, from 200 through 299.

Use real release/service policy, not these documentation example identities:

```json
{
  "target": "fixture-host",
  "endpoints": [{
    "hostname": "service.example",
    "addresses": ["192.0.2.1"],
    "path": "/readyz",
    "status": 200
  }]
}
```

```sh
bolt plan run nest::host::update_network_health --params @network-observation.json
```

The task runs without root escalation. It observes `getent ahosts` and the
client kernel's `ip -json route get` for every resolved destination, then sends
one HTTPS GET using ordinary system trust and hostname verification. Curl user
configuration and proxy/custom-CA environment are not inherited. Redirects,
credentials, arbitrary curl options and trust bypasses are not supported. The
actual remote IP must belong to the exact reviewed/resolved set. Resolution
and route observations are reacquired afterward; changed observations refuse.
The host and boot ID must remain stable throughout collection.

Output is schema 1, kind `nest_update_network_health`, with bound hostname and
boot ID, individual endpoint outcomes and `acceptance_recorded: false`. Failed
HTTP status remains an available failed observation. Missing tools, failed TLS,
DNS/NSS failures, malformed output, incomplete or changed routes/resolution and
timeouts remain unavailable/failed; empty inventories never pass. Error output
contains fixed reason codes, not response bodies, command stderr or exceptions.
No network configuration, host trust, unit state or update receipt is changed.

Commands share a thirty-second budget with at most six seconds per command;
curl additionally has a three-second connect and five-second request limit.
Loopback, unspecified, multicast and link-local addresses, including link-local
gateways, are unsupported and refuse. These constraints are explicit, not an
IPv6 fallback or an assertion that a refused network is broken. System lookup
uses the host's NSS policy, so it is not proof that a particular DNS server
answered or that the resolver has no hosts-file/cache entry. Route acquisition
and HTTPS are not an atomic network snapshot. The check proves only these
bounded client paths/statuses and system TLS trust, not service semantics,
mutual TLS, SSH recovery, Puppet environment identity, quorum or storage health.

The composed `nest::host::update_health` also accepts `endpoints`, defaulting to
an empty array for compatibility. Nonempty policy collects network observations
after managers and before the final boot observation. Network schema, kind,
hostname, boot and acceptance flags must bind to that same boot bracket; a
failed network component fails the composite. Without policy it makes no network
requests and returns `network: null`, `network_requested: false`. A passing
legacy partial composite does not imply network coverage or full acceptance.
With policy the complete network observation is retained under `network` and
`network_requested` is true. This is still not lifecycle acceptance evidence.
Rollback omits the endpoint policy or stops calling the new read-only plan.
