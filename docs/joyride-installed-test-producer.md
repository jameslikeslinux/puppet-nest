# Trusted installed TEST evidence producer

This is Nest-owned engineering source, not application code, a Joy approval
service, a production importer or a deployment controller. It does not widen the
TEST-only compile guard or create any Kubernetes resource. An independent key
generation is recoverable through the separate private-source scope, but no
production consumer root or deployed signer service is active. Disposable
fixture keys are never production trust. The isolated runtime, generation and
custody tools below do not themselves activate signing.

## Implemented and exercised

Application-owned `platform_runtime/installed_test_producer.py` reads the exact
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

    # Historical diagnostic CLI; privileged use requires admitted immutable runtime.
    python3 -B platform_runtime/installed_test_producer.py \
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
Any future scheduled producer must execute independently reviewed source in a trusted
pinned image with an independent key mount and reviewed privilege boundaries.
It must not inherit the existing TEST controller's production authority, because
that controller has none.

### Isolated execution artifact

`Containerfile.evidence` builds only from the digest-pinned trusted Nest tools
image, with binary-only `cryptography==50.0.2`, `cffi==2.1.1` and
`pycparser==3.11`. Its allowlisted context is application-owned `platform_runtime/`,
never a whole checkout, private store or credential directory. Only the fixed collector,
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

The application CI `runtime-isolation` lane builds a disposable local image and exercises actual
rootless containers: real disposable generation/readback, overwrite refusal,
caller Python/executable injection rejection, immutable source and a network
failure producing no receipt. It neither publishes an evidence image nor
provides live credentials or keys. A later managed signer requires a separately
verified registry artifact digest at the exact independently reviewed source; a local
image ID or successful fixture build is not that release receipt.

### Reviewed runtime publication

The personal `joy/joyride` application `release-evidence` job runs only after
required application checks and runtime isolation on a protected `main` push.
MR/tag/manual pipelines cannot publish it. Nest CI does not build, test or
publish application runtimes and does not trigger their release pipeline.
`release_evidence_runtime.py` also enforces these identities, exact checkout HEAD
and unmodified tracked source before login. It builds from an allowlisted
five-file context, never the whole checkout or a credential directory. The
digest-pinned toolchain and dependency versions are unchanged.

The job uses its own registry identity over stdin and an ephemeral auth file;
there is no durable credential change or application registry authority. The
destination is `registry.gitlab.joyfullee.me/joy/joyride/joyride-evidence`, with a
unique source/pipeline/job tag and no moving `latest` tag. Publication pushes the
image, reads the actual pushed digest, pulls it again from the registry by that
digest and checks repository digest, exact source revision, fixed isolated
entrypoint and Linux amd64 platform. The sanitized `runtime-release-evidence.json`
artifact is written only after readback and job-local tag/auth cleanup. It binds
the immutable image to the source commit, pipeline/job and source-file SHA256s.
It is a release identity receipt, not installed TEST evidence or Joy approval.

There are no live credentials, signing keys, cluster access, deployment commands
or signing invocation in this job. Private generation and supervised collection
remain separate. Only a successful actual main release job and independent
artifact/registry readback establish publication; fixture tests cannot establish
it. MR 11 merged at `b500350d181db4a64f5f89357b8335901907fe6f`; protected-main
pipeline 10760 and publisher job 43234 passed. Independently pulled/stopped
container source hashes matched the reviewed source. The admitted candidate is
`registry.gitlab.joyfullee.me/joy/joyride/joyride-evidence@sha256:3b3b3da4de283e91ec0aca5af1f89f43a55305b4ee2f960d3da50a29960ed535`.
It has not been activated as a signer. Application CI owns production of bytes,
not their admission to privileged execution: infrastructure must independently
pin source, hashes, entrypoint, dependencies, runtime isolation and credentials.
Never trust an application-authored receipt as its own signing authority.

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
these checks. Private-source provisioning and independent decrypt/rederive were
completed in private MR 10; operational custody acceptance is separate. Preserve
the original protected generation until backup and isolated restore are verified.
Copy only the reviewed public root into the production-only consumer contract;
do not configure TEST with a key or root. Rotation is a deliberate, serialized
trust-root replacement, not a receipt signed by the old key: stop collection and
imports, establish/recover the new managed pair, replace the consumer root and
require fresh proof. Old or pending receipts must not be grandfathered, and no
rollback can restore a revoked root silently. Keep private generations out of
logs, evidence, ordinary CI and application images throughout.

### Encrypted operational custody

`evidence_custody.py` is a supervisor-side tool, not part of the evidence image,
application, CI signing job or automatic key activation. It inspects the selected
private generation and independently supplied public root, captures only the
three exact generation files into an in-memory archive, and rechecks the source.
Its canonicalization, protected-file inspection and public-key derivation are
minimal independent infrastructure code. It imports neither the moved producer
nor key helper, and never loads a mutable application checkout with keys present.
OpenSSL CMS AES-256-GCM authenticates and encrypts that archive to the existing
PKCS7 recipient certificate before any backup write. Plaintext archives are
never staged on disk. Only the completed ciphertext is copied to an exclusive
final name under `/nest/backup/joyride-evidence`; there is no working directory,
temporary copy or active state on the backup mount.

The custody leaf must be owner-owned mode 0700; archive and completion are
single-link regular mode 0600. An existing shared/symlinked leaf is refused, not
silently repaired. The shared backup parent is not a trusted plaintext boundary:
group-writable ancestors can replace or deny access to ciphertext, but cannot
decrypt it or satisfy authenticated restore with an independent public root.
After fsync and full ciphertext readback, a canonical completion records its
checksum, length, public fingerprint and encryption format. A checksum is not a
signature or proof against deletion; incomplete archives are never restorable.

Restore requires an explicit completion, recipient certificate, independently
protected PKCS7 private key, independently selected public root and new target
under an owner-owned mode 0700 local parent. It verifies completion and ciphertext,
authenticates/decrypts in memory and accepts only the three exact regular-file
entries. It never extracts archive paths. The rederived private/public pair and
canonical manifests must match before the target is created. Fresh exclusive
mode 0600 writes, directory fsync and the reviewed generation inspector establish
the recovered result. Existing or partial generations are never overwritten or
removed. Interrupted backup/restore material stays for supervised inspection.

Example trusted-operator invocation, with identities discovered independently:

    python3 -B files/app/joyride/evidence_custody.py backup \
      --generation <protected-generation> --public-key <exact-public-hex>
    python3 -B files/app/joyride/evidence_custody.py restore \
      --completion <exact-final-completion> --target <new-private-generation> \
      --public-key <exact-public-hex> \
      --private-key /etc/eyaml/keys/private_key.pkcs7.pem

Use the locked cryptography environment and system OpenSSL with CMS GCM support.
No private bytes or subprocess diagnostics reach stdout/stderr. Only sanitized
completion identity and public inspection may enter reports. Never attach these
archives, private keys or restore directories to a task. Recovery of this archive
still depends on independent PKCS7 custody; restoring using the current recipient
key is an isolated signer recovery drill, not a disaster-recovery test of loss of
that recipient key. The helper is operator-invoked, not a scheduled backup policy.
Keep encrypted private-source recovery and its established PKCS7 custody intact.

Actual disposable-certificate tests exercise authenticated encrypted publication,
independent restore with the original unavailable, wrong public roots, tampering
even after checksum rewriting, incomplete completion, traversal/symlink members,
unsafe permissions, no-overwrite and partial-failure preservation. They do not
claim that a real managed generation has been backed up or installed.

### Ephemeral TEST Kubernetes identity

`evidence_identity.py` is a trusted operator-side provisioning helper, excluded
from the evidence image. Its administrative Kubernetes transport never enters
the collector kubeconfig. It creates a fresh per-invocation ServiceAccount,
Role and RoleBinding in `test`, after binding the supplied Pod name to the
current fully observed installed Deployment/ReplicaSet/Pod identity.

The Role permits get of only Deployment `joyride-test`, namespace-local Pod and
ReplicaSet metadata lists, and get/exec of only that exact current Pod name.
Kubernetes RBAC cannot restrict a list grant by label selector or restrict exec
to a container/command. Thus lists expose TEST namespace metadata, and exec can
reach every container and its runtime credentials in that one application Pod.
This is a real TEST database/media mutation capability, not a read-only identity.
It cannot exec another Pod, read Secrets directly, patch a Deployment, create
workloads/tokens/RBAC, inspect nodes or operate production. A replacement Pod
requires a new independently bound identity, never a namespace-wide exec grant.

Only the cluster's exact CA-verified Eyrie server and a newly issued short-lived
TokenRequest token are written to the mode 0600 child kubeconfig. The server's
actual expiry must be within sixteen minutes; requested lifetime is fifteen.
No operator client key, exec plugin, alternate server, impersonation, insecure
TLS option or signing key is copied. Sixteen actual SelfSubjectAccessReviews
check positive permissions and representative negative/ambient-authority cases.
These probes supplement exact Role/Binding readback; they are not an exhaustive
enumeration of all possible Kubernetes permissions.

The operator must provide a new owner-owned mode 0700 directory under trusted
non-writable ancestors. Intent and exact resource UIDs are persisted before
subsequent actions. Normal revocation deletes only those UIDs, ServiceAccount
first, and independently verifies absence before removing the child kubeconfig
and writing a completion. An ambiguous create/delete or failed check preserves
the private journal and any remaining resources/config for supervised recovery;
there is no automatic retry, adoption, name-only delete or broad cleanup.
Do not mount that journal directory or administrative transport in the runtime.

The command-line canary provisions, verifies and revokes an identity only:

    python3 -B files/app/joyride/evidence_identity.py \
      --directory <new-private-directory> --pod <exact-installed-test-pod>

It does not collect or sign evidence, suspend delivery, provision GitLab API
credentials, select private Hiera, install a supervisor or activate trust. A
future supervisor must keep this administrative helper outside the immutable
runtime, mount only the child kubeconfig and independent scoped GitLab read
credential, serialize collection with delivery, and revoke on normal completion.
Never interpret a successful permission canary as signed receipt acceptance.

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
