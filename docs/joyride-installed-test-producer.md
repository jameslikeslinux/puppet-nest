# Trusted installed TEST evidence producer

This is Nest-owned engineering source, not application code, a Joy approval
service, a production importer or a deployment controller. It does not widen the
TEST-only compile guard or create any Kubernetes resource. No signing key or
production trust root has been provisioned by this phase.

## Implemented and exercised

`files/app/joyride/installed_test_producer.py` independently reads the exact
application GitLab pipeline, its required non-optional check/build/smoke jobs and
the immutable multi-architecture `image.json`. It validates each job's commit and
pipeline identity, not the pipeline badge alone. It refuses truncated job lists,
missing/duplicate jobs, optional/failed jobs and mismatched artifact identity.

The fixed target is Deployment `test/joyride-test`, not a caller-selected cluster
namespace, workload or URL. Collection requires one observed/ready/available
replica, the expected Recreate strategy, all six exact application/init image
references, the controller delivery UUID, a Deployment-owned current ReplicaSet
and its one ready non-terminating Pod. Pod container specifications must match
the selected template. Full Deployment spec hash, UID/generation, Pod UID and
delivery UUID are fenced before probes, after cleanup and after the second exact
CI read. A replacement, rollout, pod restart or concurrent spec change prevents
signing. This is bounded optimistic observation, not a rollout lock: another
change after the final read invalidates freshness operationally; collect again
rather than reusing an earlier report.

`installed_test_probes.py` independently performs normal CA/hostname-verified
HTTPS checks against `https://joyride-test.eyrie`, with redirect refusal and
bounded reads/timeouts. It uses the installed management interface only for the
terminal successful delivery/artifact read and exact synthetic fixture lifecycle.
It does not ask application code to assert which HTTPS checks passed.

The exact ordered checks are:

- `https_readiness`: real TLS ingress and database-backed readiness.
- `session_csrf`: a short-lived synthetic verified session, real CSRF token,
  unauthenticated rejection, missing-CSRF rejection and logout invalidation.
  This does not exercise external login email delivery.
- `disabled_billing`: installed TEST settings require disabled Stripe and mail;
  capability is unavailable; authenticated checkout/portal/webhook return the
  disabled response while auth/CSRF gates remain enforced. These are real HTTP
  observations, not runtime packet tracing or provider acceptance. The exact CI
  disabled-billing regressions separately verify zero provider calls.
- `private_route_photo_gpx`: populate a synthetic route, GPX and processed member
  photo; anonymous and non-entitled reads fail; a synthetic entitled member can
  read route/GPX and a byte range of the generated JPEG. No real subscription,
  curated route, private input archive or waiver assent is created or imported.
- `photo_only`: route serialization includes only the photo; a retained synthetic
  ready video record remains unservable through private/public paths, the old
  prototype asset returns not found and home has no video element/reference.
  No video file is created, read or processed.
- `basemap_range`: current ODbL/OpenStreetMap metadata, normal public range GET,
  exact PMTiles version 3 magic bytes, Content-Range and digest ETag. This is not
  a fresh full-archive hash, geographical rebuild or visual painted-tile test;
  those have separate existing acceptance evidence.

Finally removes only the preallocated fixture member/route/photo derivative,
private folder and exact session. Identifiers are allocated before setup so
partial setup failure can still clean its files/session. Cleanup failure blocks
receipt creation. Member data, session bytes, management stdout and credentials
are never written to the report or failure output. Interrupted/killed collectors
still need exact fixture cleanup before retry; there is no automatic broad sweep.
The trusted invocation must be supervised and serialized with TEST delivery.

## Invocation and isolation

Run from the trusted reviewed Nest checkout, using its existing scoped GitLab
read identity, selected Eyrie kubeconfig and an isolated Python environment.
The unsigned collector uses the standard library. Signing additionally requires
`cryptography==50.0.2`, matching the selected application's locked version. The
existing Nest CI fixture lane installs that version and exercises synthetic key
roundtrips; CI has no real signing key or live producer job.

For a fresh diagnostic collection:

    python3 -B files/app/joyride/installed_test_producer.py \
      --collect-only --pipeline <exact-pipeline-id> \
      --digest sha256:<exact-index-digest> --source-head <exact-commit> \
      --output <new-private-report-path>

Arguments must be literal exact identities discovered from CI, not a moving ref.
The output path must not exist. Output is created mode 0600 with exclusive
creation/no symlink following and fsync. The diagnostic top-level kind is
`unsigned-installed-test-collection`; it deliberately has no `payload` or
`signature` envelope and cannot import into the application. Its candidate expiry
is diagnostic only. Do not turn it into a receipt later.

The separate `--signing-key <protected-file>` mode ALWAYS recollects live evidence;
it cannot accept an old report, a caller-provided check list or an approval.
It reads exactly 32 raw Ed25519 private-key bytes from a regular owner-owned,
single-link mode 0600 file without following symlinks. The key is never printed,
transmitted to application management, copied into ordinary CI or included in
output. Only after complete fresh checks and cleanup does it sign the exact
`joyride-installed-test-v1` domain and canonical payload from the application
consumer contract. Receipt UUID is fresh; lifetime is fifteen minutes; total
collection must finish within ten minutes. No signature is emitted on failure.
Do not run signing with a disposable test key and call the result trusted proof.

The local kubeconfig is an administrative authority, not narrow RBAC. The
collector's fixed target checks are application safety fences, not a substitute
for isolating its execution identity. It must never be launched from Luna's CI,
a selected application image, a runtime pod or a caller-supplied Python module.
Any future scheduled producer must execute reviewed Nest source in a trusted
pinned image with an independent key mount and reviewed privilege boundaries.
It must not inherit the existing TEST controller's production authority, because
that controller has none.

## Evidence and remaining work

A real unsigned collection against installed generation 14, source
`04fcfbe9efa62a68f820ddb86ae64c5617bb9de1`, pipeline 10665 and index digest
`sha256:1dc225fbb3f5fd6eecc300f186d9b405fb88bc38ee7b07ab79ed8dd8d3f758a6`
passed all six checks, successful delivery binding, stable three-snapshot
installation and exact fixture cleanup. No repeat rollout occurred. Nest MR 346
preserves this release and merged after all required exact-head CI jobs passed.

This is not a positive trusted-signature/import/admission canary. Remaining
parent-owned engineering is the managed producer key/public-root lifecycle,
reviewed isolated execution/deployment, independent production CI registration
and bounded receipt import, actual Joy exact-artifact/action/scope approval
provenance and a distinct production controller/topology. Do not enable
production delivery, provision production runtime state, scale dormant pods or
activate the gateway to test this source. Do not reopen completed consumer tasks.

Production/publication/payment/mail/WMATA editorial gates remain closed. Stripe
provider acceptance remains deferred, not passed and not a new blocker. Preserve
the existing Luna frontend, closed frontend canaries and uncertain browser action
journals. This engineering source does not authorize browser recovery or replay.
