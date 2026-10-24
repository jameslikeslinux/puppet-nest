# Finalize an already accepted ordinary A/B transaction

`nest::host::update_finalize` composes the installed CLI lifecycle interface over
ordinary inventory-backed Bolt transport with root escalation. It never prepares,
accepts, reboots, changes quotas, selects a release alias or adopts an extra BE.
It operates on exactly one non-console host. Fleet-wave integration and the
trusted postboot acceptance collector remain separate unfinished program work.

Pass a private JSON parameter file with exact `target`, native `transaction`,
`release` (`sha256:` plus the full manifest digest), native `hostname` and an
existing canonical `output_dir` on persistent supervisor storage:

```sh
bolt plan run nest::host::update_finalize --params @/absolute/path/finalize.json
```

The default `execute=false` reads live `nest reset status ID --format=json` and
then invokes `nest reset finalize ID --cleanup=owned --format=json --plan`.
No host mutation or native lock creation is performed by these CLI observation
commands. Supervisor retention does write small sanitized documents. Destination
and context validate before host contact; live status must be retained and
reopened before any finalize command. The status must describe an accepted,
finalizing or finalized transaction with its expected target current and next,
a changed boot and native acceptance on this exact observed boot. A historical
report, prepared-only transaction or acceptance from a different boot refuses.

Only within a separately reviewed and authorized exact host/retention scope may
the caller add `execute: true`. This runs the native finalize command once,
without `--plan`. The native CLI rechecks its host, pool, shared-state, accepted
boot, current/next and previous A/B GUID trees under the transaction lock.
The plan requires a matching finalized result and exact supervisor readback.
`execute=true` is an explicit operation request, not evidence of Joy's approval;
the first disruptive lifecycle canary remains separately Joy-gated under ^2045.
No live acceptance or finalize is performed merely to test tooling delivery.

This plan deliberately supports only the existing production ordinary lifecycle:
empty `owned_candidates` and `cleanup_receipts`. It refuses exceptional extra-BE
cleanup rather than adopting names or projecting away unsupported ownership.
Normal preparation creates no extra, so successful finalization deletes nothing
and closes the native retention boundary before a later transaction may replace
the old alternate. Both ordinary A and B survive. Snapshot policy remains
`retain_origins_no_reclamation_claim`; no snapshot retirement or reclaimed-space
claim is made. Native exceptional cleanup is not enabled by this plan.

All reports must retain the same transaction, release, host identity, preparation
boot/pool/BE trees, shared dataset, source, CLI/filter identities and phase rows.
The accepted boot is also compared. Preview must preserve state and have exact
read-only/owned/empty-candidate flags. An executed result must be finalized, not
a preview, prepared state or interrupted finalizing state. Unknown/private native
fields, including acceptance evidence bodies, are not copied into public output.
This trusts the native root-owned lifecycle assertion; it does not independently
verify the original acceptance evidence, producer resources or served catalogs.
`acceptance_independently_verified` therefore stays false.

The existing atomic publisher fsyncs and reopens content-addressed files with
`finalize-ACTION-TRANSACTION-DIGEST.json` names. Admission and outcome are retained
separately, including idempotent already-finalized observations. Equal bytes may
reuse one file; changed bytes never overwrite prior receipts. The result includes
the outcome path, digest, bytes, readback flag, native state and the `admission`
receipt. Reopen caller-backed files and materialize them through task artifacts
before completion; a container-only path is not durable on the notification host.

Transport, native, validation or publication failure stops without a second
finalize, reset, accept, catalog or reboot. Lost completion is ambiguous: inspect
`nest::host::update` observation mode or `nest::host::update_report`, diagnose the
retained status and actual host, and only then decide whether an explicit retry
is appropriate. Do not replay preparation or reboot to recreate a final report.
Native repeated finalization is idempotent only while its exact accepted boot and
A/B identities still hold. Preview is a point-in-time observation, not a lease.

Rollback stops using this new plan while preserving all native and supervisor
receipts, the mount unit and A/B recovery. Do not downgrade CLI safety or erase
state to bypass a refusal. This source interface does not establish live A/B boot,
trusted acceptance, controller restart continuity or whole-program completion.
