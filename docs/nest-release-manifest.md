# Plain Nest candidate release records

`scripts/nest-release-manifest.py` is a Python 3 standard-library consumer of
independently frozen release expectations and producer result records. It checks
exact inputs/member closure and can retain one content-addressed JSON manifest
in an existing CI artifact directory. It never builds images, queries GitLab or
a registry, copies a host root, changes an alias, or authorizes rollout.

This is the record component of R06, not completed R06/R07 delivery. Existing
stage pipelines do not yet emit these records or call this validator. The real
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

## Isolated verification

```sh
PYTHONDONTWRITEBYTECODE=1 python3 spec/files/nest_release_manifest_test.py
```

The suite uses conspicuously fixture-only sources, identities and image refs.
It executes the real CLI read-only and retention paths, tests concurrent
publishers, removes inputs before reopening the retained file, and injects
missing debug/member rows, moved pins, stale executors, wrong firmware/CPU/mode,
identity overlap, unclassified tools, failed publication and malformed JSON.
It performs no network access, Podman build, ZFS operation or live host action.
The existing all-branch CI fixture job runs this suite.
