# Plain Nest candidate release records

`scripts/nest-release-manifest.py` is a Python 3 standard-library consumer of
independently frozen release expectations and producer result records. It checks
exact inputs/member closure and can retain one content-addressed JSON manifest
in an existing CI artifact directory. It never builds images, queries GitLab or
a registry, copies a host root, changes an alias, or authorizes rollout.

This is part of R06, not completed R06/R07 delivery. The opt-in producer below
executes frozen Stage 0/1/2 candidate plans. Existing stage pipelines do not yet
invoke it or call this validator. The real
multi-project DAG, registry resource verification, output publication and alias
compare-and-swap remain separate integration work. `plans/build/manifest.pp`
still means an OCI multi-architecture index; it is not this release manifest.

## Command contract

From the repository root:

```sh
python3 scripts/nest-release-manifest.py \
  --expectations /absolute/path/expectations.json \
  --candidate /absolute/path/candidate.json
```

The default is read-only. Exit 0 means the submitted metadata reconciles with
those exact expectations. Exit 1 means invalid/unreadable input or failed artifact
retention; stderr contains a bounded error without input values or traceback.
Argument errors use argparse's ordinary exit 2. The validator does not interpret
shell code or fetch references from submitted records.

To retain the manifest, first provide an existing canonical absolute directory
on durable caller storage, then append `--output-dir /absolute/artifact/dir`.
A filename `release-<SHA256>.json` binds exact canonical manifest bytes. Publication
uses a unique temporary file, fsync, a no-clobber hard link, directory fsync and
exact byte readback. An identical concurrent writer is idempotent. A conflicting
file or symlink refuses without replacement; publication does not advance any
release pointer. Failed readback must not be treated as successful retention.
The directory is trusted local CI/supervisor storage, not an adversarial shared
writable directory or a network-publication protocol. An interruption may leave
a hidden temporary file, never a selected production release.

Stdout is one schema-1 `nest_release_manifest_validation` receipt containing the
release name, manifest and expectations digests, member count, optional path and
readback status. `resource_verification` is always `not_performed` and
`promotion_authorized` is always false. CI must retain the actual named file via
its artifact configuration; an executor-local path alone is not artifact delivery.
Before using it elsewhere, reopen the copied manifest and verify the digest.

## Expectations schema 1

The top-level fields are exactly:

- `schema`: integer 1; `kind`: `nest_release_expectations`.
- `release`: lowercase name, starting with an alphanumeric character, followed
  by alphanumeric, dot, underscore or hyphen; maximum 128 characters.
- `sources`: map of exact `nest/...` project paths to lowercase 40-hex Git SHAs.
  Config, overlay, Gentoo Portage and `nest/gentoo/haskell` are mandatory. Each
  selected producer's project must also be present. Branch names, tags and short
  SHAs are not pins. Earlier schema-1 expectation records that omitted Haskell
  are now rejected: retain those historical records, but do not silently add a
  current Haskell tip and call their original input closure complete.
- `executor`: exactly `source` and `image`. Source must equal `sources` entry
  `nest/config`. Image must be a repository-qualified OCI `@sha256:` reference
  with 64 lowercase hexadecimal digits. It records expected executor identity,
  not a proof that an image was built from that source.
- `members`: nonempty independently selected array, bounded to 1,024 rows.
- `consumers`: explicit project classification array, bounded to 128 rows.

Each member has exactly these fields:

| Field | Contract |
|---|---|
| `id` | Unique release-local lowercase token, same syntax as release |
| `stage` | `stage0`, `stage1`, `stage2`, `stage3` or `tool` |
| `project` | Corresponding `nest/stageN` or a selected `nest/tools/...` project |
| `cpu`, `variant` | Explicit lowercase tokens, never aggregate-index guesses |
| `platform` | Required token for Stage 2/3; null otherwise |
| `host` | Required token for Stage 3; null otherwise |
| `mode` | Explicit `fresh` or `refresh`, not inferred from the base name |
| `bases` | Stage 1: exact `normal` and `debug` image pins; all others, including Stage 0: exact `image` pin |
| `compatibility` | Stage 2/3: exact `kernel`, `modules_abi`, `firmware`, `bootloader` strings; otherwise empty object |
| `identity_root` | Stage 3: canonical absolute private identity input directory; otherwise null |

Selection tuples `(stage, project, cpu, platform, variant, host)` must be unique.
Stage 0 consumes one base and derives both normal/debug outputs from the same
build. Only Stage 1 consumes a base pair. Earlier experimental schema-1 records
with a Stage 0 base pair are rejected rather than silently discarding a claimed
input. Recreate expectations from the actual selected base and bind the new
canonical digest; retain old records as historical metadata, not accepted builds.
Both stages still require distinct normal/debug output references.

Stage 3's publication root is `/nest/releases/RELEASE/hosts/HOST`, distinct from
its private identity tree; equal, ancestor and descendant overlap all refuse.
This is the versioned publication destination, not the transaction CLI's required
host-local read-only ZFS generation. The later transfer/admission producer must
verify ownership, content, local mount, dataset GUID and release properties.

A consumer has exactly `project`, `decision`, `reason` and `members`. Decision is
`rebuild`, `reuse`, `defer` or `retire`; reason is bounded printable text. Rebuild
and reuse require the exact nonempty selected member IDs for that project and
thus actual output rows. Defer/retire require an empty selection and cannot be
counted as rebuilt. A reused result still needs exact source, executor, base and
compatibility identities; reusing an incompatible historic output fails rather
than relabeling it as current. If compatibility is unproven, choose defer and
keep it out of accepted required consumer scope.

All selected producer projects must be classified. The audited known tool floor
also requires explicit decisions for Bolt, PDK, Agent, Firefox, Camofox, llama.cpp,
whisper.cpp, Hadrian, Chromium, GHC, r10k and Buildah, using their lowercase exact
`nest/tools/...` project paths. This floor prevents silently dropping those known
consumers; it is not automatic discovery of future projects or legacy tag users.
The independently reviewed expectation producer must include those additional
consumers and any required release scope. A self-selected smaller matrix cannot
prove full fleet/consumer closure.

## Config CI input publication

An opt-in config pipeline with `RELEASE_INPUTS=true` and a GitLab file-type
variable `RELEASE_EXPECTATIONS_FILE` publishes an independently reviewed complete
expectations document. Select the exact config commit already named by both
`sources["nest/config"]` and `executor.source`. The executing job's checked-out
HEAD and tracked cleanliness must match that source. Pipeline/job IDs and the
config project identity are required; conflicting build/executor/candidate modes
refuse. No source, base, consumer decision or missing matrix row is selected for
the caller, and no branch tip is silently resolved into a pin.

The `Freeze release inputs` job runs
`python3 scripts/nest-release-inputs.py --expectations "$RELEASE_EXPECTATIONS_FILE"`.
It validates the existing complete schema, canonicalizes JSON, and exclusively
creates `release-inputs/expectations.json` and `release-inputs/receipt.json`.
Files and directory are fsynced and exact bytes reopened before job success.
An existing directory or symlink refuses without overwriting earlier output.
GitLab retains these two files only on success; a partially failed job is never
an accepted input producer. The receipt binds source/pipeline/job and the raw
SHA256 of the actual retained expectations bytes. Consumer variable
`RELEASE_INPUT_SHA256` uses that bare lowercase hex digest; the embedded
`expectations_digest` includes the `sha256:` prefix. Canonical publication makes
their hex payloads equal, unlike an arbitrary pretty-printed input file.

Every nonempty `RELEASE_INPUTS` value suppresses config executor builds and both
deployment jobs before their usual rules, even an invalid value or conflicting
`EXECUTOR_ONLY`/`BUILD`. The input script accepts only the exact value `true`.
Ordinary test jobs still run; neither real OS builds nor downstream triggers are
launched by this path. Without the flag, ordinary config CI behavior is unchanged.
This is a non-building input publication path, not release promotion authority.

Supply only sanitized expectations. Valid free-text reason/compatibility fields
are not secret scrubbers. The producer does not log the document or native Git
diagnostics, fetch repositories, validate registry resources, build an executor,
or prove that the selected executor exists. Download and independently verify
the exact successful input job artifact and executor architecture job before
using them; never use latest-success artifacts. Since the config SHA is shared,
a new producer source first needs its ordinary accepted executor publication;
do not pair an old executor with a new config source merely to skip that boundary.

Stage 0/1/2 candidate CI consumers are now published through their accepted
source-only merge pipelines. They acquire exact config input/executor artifacts
and retain individual results; live job-token access has not yet been exercised.
Stage 3 source pipelines are isolated from legacy host-root builds and refuse
unsupported candidate flags. Multi-project trigger/needs integration, assembly,
resource admission and Stage 3 candidate execution remain unfinished.
Rollback disables this opt-in invocation and retains prior artifacts;
it does not rewrite historical input receipts or alter any release alias.

## Candidate schema 1

The candidate has exactly `schema` (integer 1), `kind`
(`nest_release_candidate`), `release`, `expectations_digest` and `outputs`.
`expectations_digest` is `sha256:` of canonical expectations bytes, not a digest
of the original file's whitespace. The canonical encoding is ASCII JSON with
sorted object keys, compact separators, escaped non-ASCII, finite numbers and one
trailing newline. Array order is significant. Duplicate JSON keys, nonfinite
numbers and files larger than 4 MiB refuse. The imported `canonical(value)` and
`digest(value)` helpers implement this encoding for CI producers.

Each output has exactly:

- `member`: the complete corresponding expectations row, byte-value equivalent
  after JSON parsing. A changed CPU, mode, variant, base, firmware or ABI refuses.
- `producer`: exactly `project`, `sha`, `pipeline`, `job`. Project/source must
  match the frozen selection; pipeline/job are positive integers, not placeholder
  zeros or booleans. CI integration must independently read those resources.
- `executor`: exactly the expected executor object. A stale expected source or
  mismatched actual executor refuses.
- `artifacts`: Stage 0/1 require distinct `normal`/`debug` repository digest refs;
  Stage 2/tools require an `image` digest ref. Stage 3 requires a `root` object
  with exactly `path`, decimal-string `dataset_guid` and `content_digest`
  (`sha256:` plus 64 lowercase hex digits). Root path must be the exact versioned
  host destination above; duplicate dataset identities refuse.

Missing, duplicate, unexpected or partially published member rows cannot produce
a retained release manifest. Normal/debug outputs remain per CPU/variant pair;
aggregate OCI indexes never substitute for missing matrix members. Unknown
fields at every schema object boundary refuse rather than being silently copied.
The retained schema-1 `nest_release_manifest` embeds both exact `expectations`
and `candidate`, so it remains interpretable after the input files disappear.

## Trust, publication and rollback boundaries

Config executor CI now pins its Git checkout to `CI_COMMIT_SHA`, verifies that
exact HEAD after cloning even if the branch moves, and sets the OCI revision
label. The local branch name is retained at that exact commit because `bin/build`
derives Stage 3's default Puppet environment from it. Each architecture publishes
a unique pipeline/job/CPU tag through the existing remote digest-readback helper.
`bin/ci-executor-receipt record REF_FILE
JSON_FILE` opens that digest with no container network, host mounts or writable
root, checks its Git HEAD and revision label, then exclusively writes and
reopens one schema-2 `nest_config_executor_member` receipt. The input reference
must belong to the current CI registry repository/ref slug. Failed inspection,
wrong source, malformed input or an existing receipt refuses without replacement.
No submitted command output or environment is copied into the artifact.

The build job retains `executor-receipts/` as normal GitLab artifacts. The image
deployment job downloads those successful prior-stage artifacts and invokes
`bin/ci-executor-receipt refs executor-receipts`: exactly the expected Haswell,
Cortex-A53 and SiFive-U74 receipts must match this project, source and pipeline,
with distinct positive job IDs and digest references. Only after the complete
set validates are refs emitted for OCI index assembly. It never substitutes a
mutable CPU tag for a missing member. A single-CPU `BUILD` run still does not
publish an aggregate. These executor receipts are not Stage 0/1 output pairs or
a completed release manifest; they do not attest module or base-image
compatibility or GitLab job status independently. CI artifact origin and normal
job dependency success remain part of the trusted pipeline boundary.

Schema 2 also embeds `inputs`, a schema-1 `nest_config_executor_inputs` record.
CI pulls the selected Bolt base once and passes a repository-qualified digest
from Podman's image readback to `BOLT_IMAGE`; the Containerfile consumes that
exact reference. Direct Containerfile callers must likewise pass an exact base.
After normal module installation, the nested `.modules/nest` checkout fetches
the already cloned exact config commit locally and detaches there, rather than
trusting the control branch still points to that source.

Executor receipt verification pulls the exact published digest under a bounded
600-second transfer/unpack budget, then checks inputs and Git source in offline,
read-only containers with separate 180-second command limits. The OCI label is
checked independently. Static phase/timeout diagnostics never echo native
registry errors or credentials. A timeout still refuses the receipt and aggregate;
the larger transfer budget is not acceptance of an incomplete check.
Both offline checks disable Podman's automatic read-only tmpfs mounts with
`--read-only-tmpfs=false`. Neither needs writable temporary storage. This avoids
copying image-resident temporary build trees into tmpfs before the verifier starts,
while retaining the image's read-only paths and the existing verification limits.

`scripts/nest-executor-inputs.py record --source SHA --base DIGEST_REF` records
the exact top-level and nested Nest source, Puppetfile digest, and every installed
module's name, optional Git HEAD and content digest. It requires the existing
Nest, private, stdlib, reboot, Ruby task helper and KubeCM modules. Git-backed
modules may have Bolt's installer-pruned tracked deletions, but modified, added
or type-changed tracked files refuse. The nested Nest module is force-checked out
inside this build-owned image to restore the complete exact source before hashing;
the top-level and nested Nest source must be clean. This never resets an operator
checkout or a live host. The file digest covers relative paths,
file bytes, permission bits, directories and symbolic-link text; Git internals
are excluded and links are never followed. Link identities do not prove their
referents are available or compatible. The entire installed module set, including
ignored/untracked module content, participates. Missing/added/changed modules,
bytes, paths or permissions fail the subsequent exact readback. No file contents,
remote URLs, credentials or full environment enter the public receipt.

The build workspace retains `.executor-inputs.json` in the image via exclusive
creation and fsync. `check` recomputes all identities read-only and requires exact
bytes. The receipt producer runs that check in the actual published digest image,
with no network, host mounts or writable root, before retaining the embedded
sanitized identities. Failure emits no accepted receipt. The aggregate reader
requires schema 2; earlier schema-1 artifacts remain historical source/pipeline
evidence, not module-complete receipts. Do not silently upgrade them with the
current module set or rebuild old outputs merely to produce new metadata.
This records consumed modules; it does not freeze their mutable upstream refs
before installation, prove compatibility, or reproduce historical modules on
rebuild. Release producers must select the exact accepted executor digest and
compare its retained input inventory, not reinstall modules from main.

Legacy CPU tags and both `latest` executor aliases remain compatibility outputs,
not immutable release inputs. Concurrent older pipelines can still replace
those aliases out of order; use the retained digest identities, not tag recency,
for release selection. This slice does not implement release alias admission or
compare-and-swap. Rollback restores the previous CI source only for subsequent
tooling builds; preserve all already published digests and do not use a failed
receipt as a reason to launch OS builds or host actions.

These are sanitized metadata documents. Never supply private keys, tokens, full
environments, certificates or backup contents. The tool rejects unknown fields
but does not scrub secrets placed inside valid free-text reason/compatibility
fields or path values. Review/sanitize the producer payload before artifact
publication; manifests are mode 0644 and intended for normal CI artifact use.

Metadata validation cannot establish that a referenced image exists, that its
actual contents match firmware/ABI assertions, that a producer job succeeded,
or that a ZFS root is immutable/readable. Required resource readbacks, executor
labels/source verification and compatibility checks must precede acceptance or
alias replacement in the later real CI consumer. No signatures are invented.
A manifest digest is content identity, not signer identity or approval.

Do not infer a live deployment from a valid candidate or publish a new release
alias merely to exercise this validator. Existing build defaults and mutable
aliases are unchanged. Rollback stops invoking this opt-in validator and retains
previous manifest/artifact digests; it does not rebuild an old release from main,
destroy a generation, alter a host, or relax a failed admission gate.

## Frozen Stage candidate producer

`python3 /opt/nest/bin/ci-release-build --expectations FILE --member ID
--executor-receipt FILE --output-dir ABSOLUTE_DIRECTORY` is an executing build
entrypoint, not a read-only planning command. Invoke it only in an approved
Stage CI job using a pinned config executor image. It runs exactly one existing
`nest::build::stage0`, `stage1` or `stage2` candidate plan through the existing
cleanup wrapper, passing JSON parameters over stdin. It never calls a host
update plan or changes ordinary CPU/platform/latest aliases. Candidate image
publication is a real side effect and requires the build scope's authorization.

The full frozen expectations file selects one `rebuild` member. Stage 0 currently
supports only refresh of a Nest base with the server profile; raw Gentoo/fresh
bootstrap is intentionally rejected. Stage 1/2 preserve explicit fresh/refresh,
normal/debug base distinctions, CPU/platform/variant and all three repository
pins. Stage 3 and tools refuse before execution rather than falling through to
legacy defaults. Candidate/container names derive from positive CI pipeline/job
IDs, so one member must run per CI job. No arbitrary plan parameter overrides
are accepted; existing Hiera resource policy remains in effect.

Before execution, the adapter checks the Stage project's actual Git HEAD and
tracked cleanliness against `CI_PROJECT_PATH`, `CI_COMMIT_SHA` and the frozen
source selection. `CI_JOB_IMAGE` must equal the selected exact executor digest.
The selected schema-2 config member receipt is validated in its original config
pipeline context; the installed executor's source, Puppetfile and complete
module inventory are independently recomputed and must equal that receipt and
the image's retained input record. These checks repeat after execution. CI image
selection and artifact origin remain trusted GitLab/runner boundaries, not a
signature or independently queried proof that an untrusted runner used that
image. Do not accept an arbitrary user-supplied receipt as a trusted CI artifact.

The adapter derives candidate-only publication and complete frozen repository
arguments from the selection. It relies on existing registry authentication;
credentials are not command parameters or result fields. Bolt's actual JSON
return must contain the complete expected digest pair/image in the producer's
exact registry/project/variant repositories. Partial, mutable, wrong-repository
or identical normal/debug content refuses. The existing candidate plans perform
remote digest readback. No success can be produced merely by submitting output
metadata or by relabeling an old build.

The caller must provide an existing canonical absolute artifact directory. An
exclusive `.ID.started` reservation is written before any build. A failed,
interrupted or previously completed attempt cannot execute again in that same
directory. Use a fresh CI job and private workspace after diagnosis, not deletion
of the reservation to blindly replay a build. On success, exclusive `ID.json`
creation, file/directory fsync and exact readback retain a schema-1
`nest_release_member_result` with release/expectations digest, original executor
receipt and the complete `output` row for later candidate assembly. Stdout is a
small member/digest/readback receipt. Raw Bolt stdout/stderr is private temporary
data and is not published; failure emits a static sanitized diagnostic. This is
not a resumable OS build engine; GitLab job cancellation and the existing wrapper
own cleanup, while partial candidate digests remain unselected.

Stage 0/1/2 project CI implements exact expectation/executor artifact acquisition,
image selection, this entrypoint and retained `ID.json`. Live job-token permissions
and downstream successful-job binding remain unverified. Candidate assembly,
Stage 2 firmware/ABI resource verification, native multi-project DAG, release
promotion/rollback and Stage 3 frozen catalog/generation publication remain
unfinished. A successful adapter fixture or metadata compatibility string is not
hardware boot or whole-release compatibility proof. Rollback stops invoking the
opt-in adapter; preserve published candidates and receipts rather than rebuilding
historic outputs or changing live aliases.

## Isolated verification

### Opt-in frozen Stage 3 catalog

`nest::build::stage3` accepts optional `catalog_inputs`, with exactly `source`
(the full lowercase config Git SHA) and `base` (the config executor's exact Bolt
base image digest). These identify the existing retained executor input inventory,
not the Stage 2 image. Use the accepted digest-pinned config executor and its
`/opt/nest` Bolt project; do not point Bolt at a different project or modulepath.
The trusted CI invocation must select that executor and validate its retained
schema-2 receipt. This plan option alone is not an attestation of CI image use.

Frozen catalog mode requires `build=true`, `init=true`, complete `repo_revisions`,
an exact `stage2_image` and no `puppet_environment` (even an explicit empty string
refuses). The existing installed input checker verifies both config checkouts,
Puppetfile, base and every module's paths/content/permissions before container
initialization and before/after final configuration. A failed check stops the
plan. The final catalog uses Bolt `apply { include nest }`, compiled locally from
the verified executor module set, with the existing Stage 3 target facts. It does
not run `puppet agent` or fetch a mutable served catalog. Existing local identity
and profile applies retain the same executor context. Ordinary invocations without
`catalog_inputs` retain the served environment and Puppet detailed-exit behavior.

Frozen mode also requires a separately provisioned private `identityroot`; its
legacy default equal to `hostroot` now refuses before container removal, repository
creation or package work. `files/build/check-stage3-paths.py IDENTITY OUTPUT HOST`
now requires a fourth argument, `CA_SHA256`, the independently approved bare
lowercase SHA256 of the public CA PEM file bytes. `nest::build::stage3` takes it
as `identity_ca_sha256`, mandatory with `catalog_inputs`; missing, malformed or
changed pins refuse before mutation. This deliberately tightens the opt-in frozen
interface; ordinary builds without `catalog_inputs` remain unchanged. Obtain the
pin from the release's reviewed trust policy, not by automatically accepting the
current identity tree's CA. A pin selected from that same unreviewed input would
only prove self-consistency, not approved trust. This is public CA content identity,
never a key fingerprint. The checker is read-only admission, invoked locally before initialization
and before/after final configuration. Both paths must be canonical absolute paths
without symlink aliases or equal/ancestor/descendant overlap. The identity's entire
ancestry and existing output ancestors must be root-owned directories without
untrusted writers. Existing machine-id must be a nonzero lowercase 32-hex value.
The existing SSL tree must contain `certs/ca.pem`, `certs/HOST.pem` and
`private_keys/HOST.pem`. Copied SSL material permits only root/Puppet ownership,
no untrusted writers, regular readable nonempty files, protected directories and
private keys without group/other access. Links and special files refuse, including
extra files in the recursively copied source. The checker emits no identity
values, certificates, keys or key digests. Exit 1 is sanitized failure; argument
errors use argparse exit 2.

The checker reads bounded material into private process memory, compares the
certificate and private key's public keys, and requires exactly the selected host
as its single common name. Wildcards, a matching SAN with a different common name,
multiple leaf PEM objects, encrypted keys and trailing unrelated material refuse.
Native OpenSSL validates current validity, the client-auth purpose, host name and
chain against only the pinned CA bytes. Default file/directory/store trust and
inherited OpenSSL configuration are disabled. Each command is bounded to 15 seconds
and native diagnostics are discarded. Linux sealed anonymous memory supplies the
exact approved CA to OpenSSL without creating a temporary file; unsupported
OpenSSL options or missing tools fail closed. The executor requires OpenSSL 3,
Linux `/proc/self/fd` and Python's memfd/sealing support. No CA, key or cert is
generated, repaired or renewed by admission. This is not a revocation-status or
remote TLS endpoint check; no CRL/OCSP fetch or network command is performed.

After container initialization and apply preparation, frozen identity setup invokes
the same checker with `--install` inside the disposable build container. This
explicit executing mode requires root and Podman's `/run/.containerenv`; the
default invocation remains read-only. It captures machine-id and the complete SSL
tree into bounded private process memory (at most 4096 entries and 16 MiB total,
with the existing 1 MiB per-file limit). A complete metadata inventory before and
after reading detects changes to device/inode, size, ownership, permissions,
mtime/ctime or membership, including empty directories. Source admission repeats,
and the actual captured certificate/key/CA bytes undergo the same cryptographic
checks. Concurrent source changes fail the build; there is no automatic retry.

Only those captured bytes are staged under a unique mode-0700 directory on the
container's destination filesystem, with private file creation and admitted final
ownership/modes. SSL replacement removes stale files from the previous build
identity; machine-id and SSL bytes are reopened and compared before success.
Staging is removed on both success and failure. No working copy goes onto shared
`/nest` or final backup storage. Frozen Puppet identity setup no longer reopens
the live source. A partial install aborts this disposable build before profile or
package work; it is not a live-host atomic migration or a resumable repair. It
must not be invoked in a live service container. Source mutation after capture
cannot change the bytes being installed; root/Puppet writers and the executor
remain trusted, and this is not protection against a malicious privileged writer.

This does not generate machine identity, repair or alter the private input tree,
or renew credentials. Legacy initialization remains available without
`catalog_inputs`. Missing identities use their separately approved provisioning
workflow. CA selection must still come from reviewed release trust policy, not
auto-trust of the same input. Capture is per-build, not a retained immutable
private-identity generation or binding in a release receipt. Those binding and
policy interfaces remain required before enabling the Stage 3 candidate adapter.
No key hashes or secret bytes enter public receipts or diagnostics.

This is an executing build option, not a read-only command. It does not publish a
versioned root, retain an immutable private identity reference, make dynamic external data
reproducible or validate hardware compatibility. Existing rsync publication remains
legacy behavior: callers must not treat that path as an immutable generation or
use it for release-candidate success. Stage 3 CI still refuses candidate execution.
Versioned publication, identity ownership/admission and the executing Stage 3
candidate adapter must land before that boundary can be enabled. No host update,
reset, reboot, release promotion or cleanup is triggered by this option.

Rollback stops passing `catalog_inputs` and preserves accepted images/receipts;
it does not replay a partially executed build or substitute a mutable catalog into
an already accepted frozen release.

```sh
PYTHONDONTWRITEBYTECODE=1 python3 spec/files/nest_release_manifest_test.py
PYTHONDONTWRITEBYTECODE=1 python3 spec/files/ci_release_build_test.py
PYTHONDONTWRITEBYTECODE=1 python3 spec/files/build_stage3_paths_test.py
PYTHONDONTWRITEBYTECODE=1 python3 spec/files/build_stage3_trust_test.py
PYTHONDONTWRITEBYTECODE=1 python3 spec/files/build_stage3_capture_test.py
```

The suite uses conspicuously fixture-only sources, identities and image refs.
It executes the real CLI read-only and retention paths, tests concurrent
publishers, removes inputs before reopening the retained file, and injects
missing debug/member rows, moved pins, stale executors, wrong firmware/CPU/mode,
identity overlap, unclassified tools, failed publication and malformed JSON.
It performs no network access, Podman build, ZFS operation or live host action.
The existing all-branch CI fixture job runs this suite.
