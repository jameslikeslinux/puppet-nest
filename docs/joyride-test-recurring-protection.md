# Joyride TEST recurring protection

This is a private TEST-only operational boundary. It grants no production,
publication, payment, mail or frontend authority. Restore remains an explicit
operator action; there is no automatic destructive restore CronJob.

## Backup capture and publication

`joyride-test-backup` runs every three hours at minute 17, UTC. It uses the
existing trusted Nest config operational image and read-only host kubeconfig,
not a Luna-selected application image. This is an administrative workload like
other Nest backup jobs: its kubeconfig is privileged. It mounts only the final
`/nest/backup/joyride-test` subtree, the kubeconfig file, source-managed helper
and local ephemeral scratch. No SSH key, private Hiera or entire `/nest` mount
is needed. Neither app release nor ops token can change this helper/workload.

`files/app/joyride/backup.py` finds exactly one ready app and CNPG primary. It
defaults to the original fixed TEST target. A separately suspended production
candidate explicitly selects `--environment production`; it is not deployed or
enabled by TEST follow-through. Unknown environments and mismatched final
destinations are refused before capture. Neither CLI accepts arbitrary namespaces,
selectors or backup destinations.

For the selected fixed environment, the helper
hashes private/public/map files, takes a PostgreSQL custom-format logical dump,
checks it with the actual PostgreSQL archive parser, archives and verifies all
files, then rechecks file hashes and app pod identity. Concurrent file mutations
or app replacement fail the generation rather than silently publish it. This
is an online database snapshot with stable files, not a physical/WAL backup or
a transactional snapshot across arbitrary filesystem writers. It cannot promise
success under continuous media writes; retain previous complete generations and
schedule a quiet period if capture repeatedly fails. `/data/tmp` is excluded.

All generation construction occurs in `/scratch` (local `emptyDir`, bounded to
24 GiB). The complete local tar contains `database.dump`, `files.tar` and
`metadata.json`, with image identity and payload hashes. It is copied to its
unique permanent archive name on `/nest/backup/joyride-test`, fsynced, and hashed
again there. Only then is its matching `.complete.json` receipt committed and
read back. No staging directory or temporary payload is built on the backup
mount. A killed copy can leave an uncommitted permanent-name archive; it is NOT
a valid backup without a parseable matching receipt, byte count and hash. Normal
failure removes only that attempt's files. Completed generations are retained;
no automatic pruning/deletion is enabled in this initial policy.

Directories are mode 0700, archives and receipts 0600. Archives include private
application data and WMATA cache, not runtime secrets. Credential recovery remains
in the private encrypted source and existing credential backups. Never attach,
commit, publish or send these archives to Luna. Logs contain only success/failure,
an allowlisted failure category, nonsecret generation name and digest, never
exception text, subprocess diagnostics or file names. Archive parsing failures
are `files_archive_invalid`; command exit failures, timeouts, concurrent captures,
local I/O failures and stable-file mismatches have distinct categories. Unknown
exceptions become `unclassified_failure`, not their message or traceback. These
codes support diagnosis; they do not establish a transport/storage root cause or
authorize automatic retry. Preserve earlier complete generations and investigate
recurrence with bounded read-only captures rather than retrying until one passes.

The administrative helper explicitly selects kubectl's WebSocket remote-command
transport, including the PostgreSQL parser input stream. A bounded run 11808
comparison independently counted and hashed producer and receiver bytes: the
WebSocket transfer matched the complete 59320320-byte archive, while the legacy
transport returned zero but delivered only 54546432 bytes and failed tar parsing.
Source hashes remained unchanged. This isolates a binary exec-stream truncation
at that transport seam; it does not assign a lower-level Kubernetes/network cause.
The selection introduces no retries, changes no cluster-wide transport settings
and does not weaken tar/member/hash or completion-record validation. Real managed
capture, publication and isolated restore must pass after the reviewed change is
installed before the repair is accepted.

## Explicit isolated restore

1. Suspend the backup schedule and wait for the active Job if inspecting a
   generation in flight. Do not create concurrent Jobs; the helper also locks.
2. Select a generation with parseable `complete=true` metadata. Verify its exact
   archive basename, byte count and SHA-256 before opening it. Never accept an
   orphan archive or infer completeness from its name/mtime.
3. Copy it to restricted local staging. Check the outer tar has exactly the three
   named regular files, no links or traversal; verify the inner payload hashes
   against metadata. Validate inner tar members as regular files/directories
   within `private`, `public` and `maps`; never extract with unrestricted paths.
4. Create a NEW disposable PostgreSQL database, rejecting preexisting names.
   Restore with `pg_restore --exit-on-error --no-owner --role=joyride`, then run
   installed application migrations/checks with only that process's DATABASE_URL
   redirected. Restore files into a NEW restricted local root, not the live PVC.
5. Exercise installed request handlers against the isolated DB/root, including
   entitlement denials and exact private file/range parity. For a currently empty
   service, label that restore empty; use supplied private inputs and explicitly
   synthetic membership only in disposable state for populated acceptance.
6. Remove only run-created disposable objects, verify absence and live database
   continuity, then resume the schedule. Live restore/replacement or data deletion
   is separately owner-gated, never inferred from a successful isolated drill.

The preceding populated isolated drill is recorded in
`build/joyride-run11767/populated-restore-and-scheduled-importer.md`. That is not
proof that this new recurring workload has run or its publication restored.
Require fresh managed-Job and final archive restore evidence before acceptance.

## Application monitoring

`joyride-test-monitor` runs every two minutes, without credentials, service-account
token, database or file mounts. It probes only fixed anonymous web Service paths:
readiness (including DB), CSRF/session shell contract, current basemap metadata,
and actual HTML homepage. It refuses redirects, bounds body size/time and logs
no response bodies. NetworkPolicy admits it only to the public listener, never
ops or trusted TEST port 8002. This does not test paid membership, mail, a real
browser, external TLS, tile coverage, worker throughput or upstream WMATA health.

`PrometheusRule test/joyride-test`, selected by existing kube-prometheus-stack
instances, warns when monitor success is absent/stale or backup has no success
within four hours. A Job is successful only after every probe/publication check
passes. Verify the rules are loaded/evaluated in live Prometheus, not merely
that Kubernetes accepted them. Existing Alertmanager routing owns notification
delivery; do not claim an actual delivered notification from rule presence.

Fixtures are explicitly synthetic:

    PYTHONDONTWRITEBYTECODE=1 python3 spec/app/joyride/test_protection.py

They cover copy/readback failure, preserving the previous generation, private
permissions, unsafe archives, file mismatch and fail-closed monitor responses.
They do not replace actual backup/restore and live monitoring acceptance.
