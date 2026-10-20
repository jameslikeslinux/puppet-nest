# Trusted installed TEST evidence producer

This is Nest-owned engineering source, not application code, a Joy approval
service, a production importer or a deployment controller. It does not widen the
TEST-only compile guard or create any Kubernetes resource. No managed signing key
or production trust root has been provisioned. Disposable fixture keys are never
production trust. The isolated runtime and key-generation tools described below
are implemented and exercised, not a deployed signer service.

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

### Isolated execution artifact

`Containerfile.evidence` builds only from the digest-pinned trusted Nest tools
image, with binary-only `cryptography==50.0.2`, `cffi==2.1.1` and
`pycparser==3.11`. Its context is `files/app/joyride`, never an application
checkout, private store or credential directory. Only the fixed collector,
probes, key helper and entrypoint enter the runtime source directory. The image
does not contain a key, kubeconfig, GitLab identity, member database or app code.
The GitLab API target is explicitly fixed to `gitlab.joyfullee.me`, independent
of the caller's working directory and default host.

The fixed entrypoint uses Python isolated mode, a root-owned image source path,
and a clean environment. Caller `PYTHONPATH`, `PYTHONHOME`, working-directory
modules, executable search path, proxies and CA overrides are not inherited.
Only `collect` and `key` operations exist. Credentials, when deliberately mounted
by the trusted supervisor, are read from `/credentials/kubeconfig` and
`/credentials/gitlab`. The caller must enforce rootless Podman, read-only root,
all capabilities dropped, no privilege escalation, bounded PID/memory/CPU limits
and private ephemeral `/scratch`. Never mount the engine socket, host filesystem,
application checkout or a writable source directory. Runtime mounts are trusted
supervisor inputs, not a safe interface for an untrusted agent to select.

Key creation/inspection is offline and must use `--network=none`. Collection
needs only the normal TLS Kubernetes/GitLab/TEST endpoints. A signed collection
additionally mounts the chosen private generation read-only and one private
output directory read-write; it never mounts production credentials. These
container restrictions isolate the process filesystem, not Kubernetes authority.
An administrative kubeconfig is still administrative even inside this image.
Do not call the current exercised path narrowly RBAC-scoped.

The existing Nest CI lane builds a disposable local image and exercises actual
rootless containers: real disposable generation/readback, overwrite refusal,
caller Python/executable injection rejection, immutable source and a network
failure producing no receipt. It neither publishes an evidence image nor
provides live credentials or keys. A later managed signer requires a separately
verified registry artifact digest at the exact reviewed Nest source; a local
image ID or successful fixture build is not that release receipt.

### Reviewed runtime publication

The separate `Publish Joyride evidence runtime` Build job runs only after the
required Test stage on a protected `main` push in `nest/config`. MR/tag/manual
pipelines, partial CPU builds and executor-only pipelines cannot publish it.
`release_evidence_runtime.py` also enforces these identities, exact checkout HEAD
and unmodified tracked source before login. It builds from an allowlisted
five-file context, never the whole checkout or a credential directory. The
digest-pinned toolchain and dependency versions are unchanged.

The job uses its own registry identity over stdin and an ephemeral auth file;
there is no durable credential change or application registry authority. The
destination is `registry.gitlab.joyfullee.me/nest/config/joyride-evidence`, with a
unique source/pipeline/job tag and no moving `latest` tag. Publication pushes the
image, reads the actual pushed digest, pulls it again from the registry by that
digest and checks repository digest, exact source revision, fixed isolated
entrypoint and Linux amd64 platform. The sanitized `evidence-runtime.json`
artifact is written only after readback and job-local tag/auth cleanup. It binds
the immutable image to the source commit, pipeline/job and source-file SHA256s.
It is a release identity receipt, not installed TEST evidence or Joy approval.

There are no live credentials, signing keys, cluster access, deployment commands
or signing invocation in this job. Private generation and supervised collection
remain separate. Only a successful actual main release job and independent
artifact/registry readback establish publication; fixture tests cannot establish
it. This source change does not yet claim that such a release has occurred.

### Private generation lifecycle

`evidence_key.py` implements `create <absolute-new-generation>` and
`inspect <absolute-existing-generation>`; the image exposes these through
`key create` and `key inspect`. The caller supplies an independently managed
mode 0700 private parent. All ancestors must be non-symlink directories owned by
the executing identity or root, without group/world write permission. The store
and generation must be owned by the executing identity with exact mode 0700.

Create exclusively makes a new generation, writes and fsyncs the raw 32-byte
mode 0600 signing key, canonical public manifest and completion marker, then
fsyncs the generation and parent directories. Inspection rederives the public
key/fingerprint from the protected private key and checks the exact canonical
manifest and completion marker. Private files must be owner-owned regular
single-link mode 0600 files. Only the public key, algorithm and SHA256 public-key
fingerprint can reach stdout. Errors are bounded and do not print exception
messages or paths containing credential material.

An existing generation is never overwritten or repaired. Failed creation leaves
partial material for supervised inspection, not automatic regeneration or
deletion. A second generation has a different fingerprint but activates neither
generation. There is no active pointer, key export, consumer trust mutation,
automatic rotation or self-issued owner approval. Never create a real generation
in an ephemeral job, source checkout, CI artifact directory or public report.

Before a real generation may sign, provision it through the existing encrypted
private-source/managed-secret process, independently read back the managed
private/public pair and validate a restricted backup plus isolated restore using
these checks. No such real provision/backup/restore has happened. Preserve the
original protected generation until recoverable managed storage is verified.
Copy only the reviewed public root into the production-only consumer contract;
do not configure TEST with a key or root. Rotation is a deliberate, serialized
trust-root replacement, not a receipt signed by the old key: stop collection and
imports, establish/recover the new managed pair, replace the consumer root and
require fresh proof. Old or pending receipts must not be grandfathered, and no
rollback can restore a revoked root silently. Keep private generations out of
logs, evidence, ordinary CI and application images throughout.

## Evidence and remaining work

A real unsigned collection against installed generation 14, source
`04fcfbe9efa62a68f820ddb86ae64c5617bb9de1`, pipeline 10665 and index digest
`sha256:1dc225fbb3f5fd6eecc300f186d9b405fb88bc38ee7b07ab79ed8dd8d3f758a6`
passed all six checks, successful delivery binding, stable three-snapshot
installation and exact fixture cleanup. No repeat rollout occurred. Nest MR 346
preserves this release and merged after all required exact-head CI jobs passed.

The isolated image also completed the real unsigned collection on this unchanged
TEST generation with ordinary TLS and exact cleanup. Its temporary flattened
kubeconfig was removed; the existing GitLab config was mounted read-only; no key
or production credential was mounted. Independent readback found zero fixture
members/routes, evidence, owner approvals or production deliveries and unchanged
deployment/Pod/runtime fences. This exercises actual containerized collection,
not just a container's startup or an HTTP readiness badge.

This is not a positive trusted-signature/import/admission canary. Remaining
parent-owned engineering is actual managed key/public-root provisioning and
recoverability, exact reviewed runtime publication/deployment and scoped
execution authority, independent production CI registration
and bounded receipt import, actual Joy exact-artifact/action/scope approval
provenance and a distinct production controller/topology. Do not enable
production delivery, provision production runtime state, scale dormant pods or
activate the gateway to test this source. Do not reopen completed consumer tasks.

Production/publication/payment/mail/WMATA editorial gates remain closed. Stripe
provider acceptance remains deferred, not passed and not a new blocker. Preserve
the existing Luna frontend, closed frontend canaries and uncertain browser action
journals. This engineering source does not authorize browser recovery or replay.
