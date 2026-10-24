# Release-bound Hermes generation retention

`nest::app::hermes::retain_generation` adds explicit durable holds to the existing
full-home generation helper. Ordinary generation-count retention keeps its newest
N archives PLUS every held archive. Multiple releases may hold the same archive;
removing one hold does not release another. No expiry, background service, restore,
new capture, pruning invocation or archive deletion is added by this interface.

## Source floor and authority

Before relying on any hold, install this helper on EVERY pruning writer, including
scheduled backup executors and manually pinned older executors. Existing helpers
without hold support ignore hold files. Publishing one new executor or observing
one new source checkout does not prove all writers adopted it. Retire old scheduled
and in-flight producers through their ordinary managed configuration; never stop a
backup or alter production schedules merely to test these interfaces. This is a
cooperating-writer protocol in the existing trusted private backup directory, not
an access-control barrier against the backup account or an old implementation.

Holds retain additional storage without a time limit. The release owner must
review capacity, the backup recovery scope and the condition for eventual release.
Source installation and a held archive do not authorize reset/reboot, restore,
release promotion, cleanup or data loss. Never release a hold automatically after
a failed or ambiguous lifecycle phase, or merely because its original age budget
has elapsed. No real archive needs to be held or released to test installation.

## Inventory-backed interface

Run `bolt plan run nest::app::hermes::retain_generation --params @PARAMS.json`
from the configured Nest project. The JSON parameters are:

- `target`: exactly one canonical inventory backup host, using ordinary Joy/Bolt
  transport with the existing root escalation and backup-user Podman namespace.
- `action`: exactly `hold`, `check-hold`, or `release-hold`; no default action.
- `hold_id`: alphanumeric first, then alphanumeric, underscore or hyphen, at most
  64 characters. Choose one unique stable ID for this release's exact requirement.
  It is independent of a checkpoint, host update transaction ID or digest.
- `release`: exact runtime manifest digest, `sha256:` plus 64 lowercase hex digits.
- `checkpoint`: exact existing full-home generation, not `latest`.
- `expected_sha256`: independently retained archive SHA256, 64 lowercase hex digits
  without a prefix. This is distinct from the release-manifest digest.
- `max_age_seconds`: required for `hold` and `check-hold`, 1 through 604800;
  FORBIDDEN for `release-hold`, which does not establish freshness.
- `backup_dir`: existing private backup directory; default `/nest/backup/hermes`.
- `user`: existing backup account; default `joy`.
- `required_profiles`: unique nonempty profile array; defaults remain Talon, Star,
  Beryl and Quill. Shared config, auth and Kanban members remain mandatory.

The plan uploads a unique temporary helper and removes it on exit. It does not
initialize backup storage, repair permissions or silently choose a generation.
It runs one native action and returns its native stdout inside the ordinary Bolt
result. Parse and inspect that JSON, not just the plan exit. Transport or retention
ambiguity never triggers capture, prune, another hold ID, retry or direct SSH.

The helper also supports the same three action names directly, with the matching
`--backup-dir`, `--checkpoint`, `--expected-sha256`, `--hold-id`, `--release`, repeated
`--required-profile`, and (only for hold/check) `--max-age-seconds` arguments.

## Locking, publication and readback

`hold` takes the existing nonblocking exclusive `.generation.lock`, the SAME lock
used by capture/pruning. While holding it, the existing verifier checks the exact
completed generation: private owned regular files, full-home format, required
members/profile coverage, counts, archive SHA256 and publication age after hashing.
Only then does it publish `.generation-hold-ID.json`, mode 0600, using fsync,
no-clobber hard-link publication, directory fsync and exact parsed readback. The
lock remains held from verification through publication; pruning cannot run in
the verification/publication gap. Repeating an identical hold is idempotent and
does not rewrite it. Rebinding the same ID to another release, archive, digest or
profile set refuses. No archive/metadata bytes are copied into the hold.

`check-hold` takes a nonblocking shared lock, validates exact hold ownership and
scope, then repeats full archive verification and current freshness. It writes
nothing to backup storage. Filesystem access times may advance. A stale or corrupt
held archive FAILS verification but remains protected from pruning. A hold preserves
availability, not freshness, application consistency, integrity against external
writers, filesystem loss or demonstrated restore usability.

`release-hold` takes the exclusive lock and requires the exact existing ID,
release/checkpoint/digest/profile binding. It unlinks ONLY that hold, fsyncs the
directory and checks absence. It neither hashes the archive nor tests its age,
prunes, deletes a backup or releases other holds. It still requires existing safe
backup/lock/archive/metadata files; missing storage is not repaired. A missing hold
refuses rather than inventing evidence of a previous release. After an ambiguous
release, inspect the exact native hold and archive; do not replay host phases.

`check-hold` also returns `verification`, the existing generation-verification
document collected under the same shared lock. This binds age, counts and archive
digest to the hold without a second archive scan. Hold creation and release do
not return that field.

Results have schema 1, kind `nest_hermes_generation_retention`, exact `action`,
allowlisted `hold`, boolean `held`, `readback_verified: true`, `restore_verified:
false` and `execution_authorized: false`. They expose identities/counts only,
not private member content. These are native producer observations, not durable
supervisor artifact receipts. Reopen/copy the safe result onto persistent caller
storage and retain it through the existing task artifact path before completion.

## Pruning and failures

Both ordinary post-capture retention and explicit `prune` validate ALL durable
hold records before any deletion. Unknown/duplicate fields, excessive bytes,
malformed names, symlinks, special files, public permissions, hard links, missing
archives, unsafe files or mismatched generation receipts refuse the ENTIRE prune.
They are not treated as absent holds. Held generations stay in addition to newest
N, not instead of them. Pruning reads identity/count metadata but does not rehash
every held archive; `check-hold` is the explicit full-byte check.

A failed write may leave a published hold despite a missing success result. Keep
it and observe exact state; do not delete it to retry. A damaged/dangling hold can
block later pruning and consume more capacity. Repair requires diagnosis under
the trusted backup account, not automatic deletion or weakening the verifier.
A capture can have published successfully before its later pruning refuses;
inspect its actual metadata instead of recapturing to manufacture success.

## Compatibility, rollback and remaining lifecycle work

Existing capture, verify and cleanup arguments retain their meaning. Verification
alone remains an observation, not a retention hold. Host update preparation now
requires schema 4: every nonempty Hermes backup prerequisite adds an exact
`hold_id`. Schemas 1 through 3 remain usable for planning and stored observation,
but cannot initiate transactional preparation. `nest::host::check_update_backup`
validates the complete requirement and supervisor destination, invokes only
`check-hold` for the policy release, and retains the allowlisted hold and native
verification together. All selected prerequisites are checked before the first
reset and checked again for each affected host at initiation. Missing holds,
wrong release/generation/coverage, stale archives, busy locks or missing supervisor
readback stop new resets without capture, hold creation or retries.

The retained receipt includes `hold_checked: true`; `retention_lease` remains
false. A trusted backup account can explicitly release a hold after observation;
the observation is not a lock held across reset or proof that all pruning writers
use hold-aware source. Writer-source admission and transaction-wide rollback and
retirement policy remain required before claiming end-to-end retention. No hold
is auto-created/released by host preparation, accept, finalize or successful CI.

Rollback stops new retention calls and preserves holds and archives. DO NOT run
an older prune implementation against a directory with active holds. Keep a
hold-aware pruning source until all holds have been explicitly retired according
to their real release conditions. Unholding is not permission to delete the last
known usable recovery path. No real backup, host reset/reboot or restore is proven
by isolated fixture coverage.
