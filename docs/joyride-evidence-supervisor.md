# Operator-only installed TEST evidence supervisor

`nest::service::joyride_evidence` installs independent infrastructure orchestration
on Owl. It is not an application runtime, an application CI job, an approval
service, a listener, a timer or a production delivery controller. Merely applying
its files does not collect fixtures, sign a receipt or activate a consumer root.
Application runtime production remains exclusively in `joy/joyride` CI.

## Managed installation and admission

The class explicitly selects `private/joyride/evidence-supervisor.yaml` through
its body-local scope before requesting the existing encrypted keys. Other host
and Kubernetes catalogs do not select that scope. The private generation is
unchanged; independent encrypted backup/restore evidence remains in run 11854.
Only Owl includes the service. The root-owned admission config and two reviewed
infrastructure scripts are installed under `/etc/joyride-evidence` and
`/opt/joyride-evidence-supervisor`. The protected state directory is
`/var/lib/joyride-evidence`, owned by the Nest operator, mode 0700. Credentials
are mode 0600, no filebucket backup or diffs. Signing material is stored there
in its original base64 format; only an explicit signing invocation stages a raw
session-local copy. No credential is supplied through command arguments.

The script has a fixed independently reviewed evidence image digest, source
revision, public root, isolated entrypoint and source-file SHA256 inventory.
It derives the managed public key independently with host OpenSSL, verifies
rootless Podman, pulls using the separate read_registry-only identity, checks
actual image metadata and reads root-owned non-writable source bytes from a
stopped container. It never imports application source into the operator.
The application publisher cannot change these constants or its admission config.
Updating them requires another reviewed infrastructure change, not a branch tip,
a moving tag or an application-authored release receipt alone.

Run as the unprivileged Nest operator, from the normal inventory-backed Bolt
workflow. First run only `admit`:

    bolt command run 'python3 -I -B /opt/joyride-evidence-supervisor/evidence_supervisor.py admit' --targets owl --stream

Use `nest::puppet::deploy` and the normal targeted `nest::puppet::run` path for
installation. Do not copy credentials or scripts into place as an ad-hoc deploy.
The image is application-produced but independently admitted before any live
credential mount; no cluster or signing authority enters application CI.

## Collection and signing

The explicit `collect` and `sign` operations require literal independently
verified application pipeline ID, immutable index digest and source commit:

    python3 -I -B /opt/joyride-evidence-supervisor/evidence_supervisor.py collect \
      --pipeline <exact-successful-application-pipeline> \
      --digest sha256:<exact-installed-index> --source-head <exact-source-commit>

`collect` deliberately omits the signing-key mount and produces nonimportable
unsigned diagnostics. `sign` always recollects fresh installed evidence; it
cannot sign an old diagnostic, caller-supplied checks or Joy approval. Neither
operation imports proof into production or grants publication/launch permission.
Only a completed session with a still-fresh receipt may be considered for a
separately reviewed consumer import.

A host file lock serializes local invocations. An incomplete retained session
blocks a replacement invocation. The supervisor durably records intent before
CAS-suspending only the TEST delivery CronJob. It waits at most ninety seconds
for its owned Jobs to terminate, requires an empty exact controller journal,
and preserves the full CronJob spec against concurrent maintenance. Suspension
is not a distributed rollout lock: a late scheduler/other administrator may still
race it. Repeated quiescence and the collector's deployment/pod/runtime fences
reject such changes rather than asserting global exclusion.

The infrastructure identity helper binds the exact ready TEST Pod, creates a
short-lived per-invocation identity, and performs sixteen actual effective
permission checks. Only that child kubeconfig and a separate project-scoped
read_api credential enter collection. No administrative kubeconfig, host home,
checkout, engine socket, production identity or broad source tree is mounted.
RBAC permits TEST metadata lists and exec into the exact bound Pod; exec can
reach its runtime credentials and database, so this is not read-only authority.

The actual runtime is a rootless container running as container UID/GID 10001,
with read-only root, no capabilities, no privilege escalation, bounded CPU,
memory and PIDs, and private ephemeral scratch. Ordinary rootless mapping is
used instead of `keep-id`, whose local namespace/image setup timed out during
the real no-credential startup probe. Only session-local credential copies and
the output directory are mapped to the subordinate identity using `podman
unshare`; original operator credentials are never chowned. Unsigned collection
has three narrow mounts; signing adds only the exact raw session key read-only.
Network access is necessary for CA-verified Kubernetes/GitLab/TEST HTTPS; this
host container is not claimed to have an egress allowlist or namespace sandbox.

The admitted collector checks exact CI and six ordered real installed probes,
cleans exact synthetic fixtures, fences the installation again and writes one
exclusive receipt. The supervisor independently validates its target, artifact,
check list and freshness. A signed receipt additionally passes independent
OpenSSL Ed25519 verification against the infrastructure-pinned public root.
It then revokes the exact resource UIDs, removes temporary token/key copies,
records verification, CAS-resumes the same otherwise unchanged CronJob and
records completion. Receipt lifetime remains fifteen minutes, not indefinite
approval. No member mail, payment, legal assent or real private route is needed.

## Interruption and recovery

There is no automatic replay or broad sweep. Any ambiguous failure preserves the
private session, exact operation/container/resource UIDs and controller state.
The controller remains suspended after a post-suspension failure; a failure can
also retain subordinate-owned staged files or an expired child identity. This
is an engineering recovery obligation, not an owner-decision prompt.

Before continuing, inspect the exact private journal locally without attaching
credentials. Establish whether a container still runs, whether synthetic fixture
cleanup completed, whether the same Deployment/Pod persists and which resource
UIDs actually exist. Stop only the positively identified session container if
necessary; revoke only its journaled UIDs, verify absence and dispose of only
its staged token/key copies. Use `podman unshare` for exact subordinate-owned
files, never a broad recursive chown of state, home or storage. Reconcile the
same CronJob UID/spec and resume it only after that work is safe. A timeout or
missing receipt is not proof collection never ran. Never mark a failed session
completed merely to bypass the replacement guard or sign its old output.

The public acceptance report should contain only artifact/source identity,
permission-check count, installation fences, cleanup/revocation confirmation,
controller readback and signature verification result. Do not attach the state
directory, raw receipt, kubeconfig, registry auth, token, key or rendered private
catalog. Existing payment/mail/private-data and production-consumer gates remain.

## Verification scope

Focused infrastructure fixtures exercise immutable metadata/source rejection,
mount isolation, CAS/quiescence, interrupted-session refusal, real disposable
OpenSSL signature verification, successful cleanup ordering and failure journal
preservation. These are not installed signing acceptance. The actual independent
private credential pull/API canaries are recorded by private MR 11. The actual
managed installation/admission/collection result must be recorded separately.
