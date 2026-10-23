# Native candidate result assembly

`scripts/nest-release-assemble.py` assembles a complete architecture-specific
candidate manifest from actual successful native GitLab bridges, jobs and member
artifacts. It uses the existing discovery, binder and manifest schemas. It does
not build, trigger, retry, promote aliases, transfer host roots or operate hosts.
It is an R06/R07 integration boundary, not the complete native release graph.

## Invocation

From the config root, using the existing authenticated `glab` installation:

```sh
python3 scripts/nest-release-assemble.py --assembly /absolute/assembly.json
python3 scripts/nest-release-assemble.py --assembly /absolute/assembly.json \
  --output-dir /existing/canonical/artifact/directory
```

The default performs authenticated GETs only and prints a small digest/count
summary. With `--output-dir`, the existing no-clobber publisher retains and
reopens two content-addressed JSON files: `manifest_path` is the existing
`nest_release_manifest` schema; `path` additionally retains exact native resource
observations, original input/result artifact hashes and the executor receipt
digest. Neither file is an alias, signature or deployment authorization. A failed
second publication may leave an unselected first artifact; it cannot produce a
successful two-file readback receipt. Prior files are never overwritten.

Exit 0 means full acquisition, validation and any requested local readbacks
passed. Refusal returns 1 with a static diagnostic; invalid arguments return 2.
Selected member/job names and input policy reasons remain ordinary input data;
review retained artifacts for sanitization before sharing. Raw API errors and
native stderr are not printed.

## Assembly request schema 1

The fields are exactly `schema`, `kind`, `expectations`, `executor_job` and
`producers`:

- `schema` is integer 1 and `kind` is `nest_release_assembly`.
- `expectations` is the existing complete `nest_release_expectations` record,
  with the final actual member bases selected after predecessor binding. It must
  include every member and every required consumer decision. Do not supply
  predicted future output digests or silently omit unfinished members.
- `executor_job` has exactly the positive integer fields `pipeline` and `job`,
  naming the successful architecture-specific config executor producer.
- `producers` maps every expected member ID, and no other keys, to the existing
  native discovery selector: `project`, `member`, `root_pipeline`, `bridge`,
  `job_name`, `input_pipeline`. See [native discovery](nest-release-native-discovery.md).
  At most 128 members are admitted by this helper. A selector names the existing
  direct config bridge, actual member job name and unique `Freeze release inputs`
  job in the explicitly selected input pipeline; no mutable latest-success reads.

All members in one invocation must share an executor architecture and exact
executor image. CPU variants may differ within that architecture; normal/debug,
platform/boot compatibility and Stage 3 private identity/generation distinctions
are preserved. Separate architecture manifests are required until a reviewed
cross-architecture release envelope is implemented. This helper does not pretend
that one amd64 executor digest covers ARM or RISC-V.

## Acceptance contract

Every native edge is independently acquired through the existing discovery
checks: required successful bridge, exact downstream project/source/ref,
successful leaf pipeline, no outgoing trigger loop, no hidden failed/tolerated
jobs, exact successful unerased member/input jobs and complete paginated lists.
The original frozen input and result bytes are hashed and reopened. Each member
result must validate against its original publication, same release/source
closure, exact final selected member and independently selected executor. The
retained executor receipt must equal the independently queried receipt by digest,
including module inputs, not merely carry the same image string. One producer
job cannot stand in for multiple members.

The original member consumer decision must be `rebuild`. A final `reuse` decision
can select that exact already-produced native result, but does not permit
relabeling a different release, config source, base or executor. Cross-release
reuse needs a separate explicit provenance contract and currently refuses.

After complete manifest validation, every edge, input/result byte selection and
executor receipt is acquired again. A retried/moved/erased job, changed artifact,
newly hidden failure or parent status transition refuses; it never retries work.
This is bounded observation, not a server-side snapshot or artifact signature.

## Verification and remaining work

Offline tests exercise real discovery/binder validation for all Stage 0/1/2/3
and tool result shapes, complete matrix selection, retained normal/debug pairs,
Stage 3 identity/root refusal, changed sources/bases/decisions, failed or tolerated
native resources, executor-module substitution, acquisition races, mixed
architectures, static failures and the actual CLI's durable readback. Fake
GitLab/registry values are test fixtures, not live candidate evidence. Ordinary
source CI runs the suite.

Production job-token permissions, real candidate result acquisition, resource
existence/CPU/ABI admission, automatic native graph generation and per-edge input
freezing remain unverified here. Old-executor -> OpenBolt -> new-executor bootstrap
requires distinct accepted phases; neither same-source assembly nor discovery
may relabel those boundaries into a cycle. Complete cross-architecture program
assembly, promotion/rollback policy and host lifecycle integration remain open.
No OS/tool candidate build is launched simply to manufacture assembly evidence.
The disruptive reset/reboot canary remains separately owner-gated.

Rollback stops invoking this optional helper. Previously retained expectations,
results, manifests, aliases and rollback artifacts are unchanged. Preserve failed
job evidence; do not rebuild or replay a host operation to fill a report gap.
