# Native same-source release graph

`scripts/nest-release-graph.py` extends the existing frozen-input publisher,
base discovery/binder, candidate route and final assembler. It is a GitLab CI
compiler, not an agent shell scheduler or a new update service. It does not
promote aliases, deploy configuration, reset/reboot hosts or restore backups.

This implements the same-source scheduling boundary. It does not complete the
separate old executor -> OpenBolt -> distinct successor config bootstrap, the
multi-architecture program envelope, production resource/ISA/ABI acceptance,
source-owned specialized executor admission or the host transaction lifecycle.

## Operator input

After reviewed source is installed at `main`, an explicitly authorized build
may select `RELEASE_GRAPH=true` and the GitLab file variable
`RELEASE_GRAPH_FILE`. Supported initial sources are API, web and trigger, never
push, MR, schedule, native downstream or parent pipeline. Source publication
alone does not select graph execution. Do not run a candidate build merely to
test this interface or infer build/rollout authority from these instructions.

The JSON request has exactly:

- `schema`: integer 1.
- `kind`: `nest_release_graph`.
- `expectations`: the existing complete schema-1 release expectations, including
  all known consumer rebuild/reuse/defer/retire decisions, immutable seeds,
  selected source closure, member compatibility and exact executor image.
- `executor_job`: exactly `pipeline` and `job`, positive integer identities of
  the already accepted config executor resource.
- `nodes`: one node for every rebuilt member, no reused/deferred/retired node.
  The graph is bounded to 32 rebuilt members and one executor architecture.
  Use separate architecture graphs; never relabel another architecture receipt.

Every node has exactly:

- `member`: an existing member ID; it is also the deterministic node name.
- `job_name`: the actual required native downstream candidate job name, beginning
  with `Candidate `. Select it from reviewed repository CI, not an inferred CPU
  convention. The actual pipeline must contain exactly one matching job.
- `placement`: null except for Stage 3, where it is the canonical absolute
  runner-local placement-file path used by the existing Stage 3 contract.
  This is not a file upload, dataset allocator or GUID substitution. The file
  must still match the final, rebound expectations digest when execution starts.
- `bindings`: an empty list for independently pinned seed inputs, or the complete
  set of this member's base slots. Each edge has exactly `base`, `producer`
  (another rebuilt member ID) and `artifact` (`normal`, `debug` or `image`).

For example, a fresh Stage 1 node binds both `normal` and `debug` slots to those
roles from the same Stage 0 producer. A fresh Stage 2 node binds `image` to its
Stage 1 producer's `debug`; a fresh tool binds `image` to Stage 1 `normal`.
Stage 3 uses the matching Stage 2 image/platform/compatibility. Existing recipe
CPU/variant/fresh/refresh checks apply; graph edges cannot override them.

Partial pairs, duplicate/unknown nodes, incomplete rebuilt coverage, cycles,
unsupported projects, incompatible bases, mixed architectures and variable
expansion in input are refused. Seed digests remain reviewed immutable inputs,
not guessed future output digests. No build job is emitted for reuse, defer or
retire decisions, and no new compatibility claim is made for those consumers.

## Native topology and failure handling

The compiler job writes, fsyncs and reopens `release-graph/request.json`,
`graph.yml` and `receipt.json`. The receipt binds their byte hashes and exact
source/pipeline/job, with execution explicitly not started. Existing CI retains
only successful publication. No previous job-local directory is overwritten.

`Run release graph` includes the generated artifact as a config child pipeline.
Its `Release node MEMBER` jobs use native multi-project config triggers and
`strategy: mirror`. Each node has `needs` only on its actual predecessors;
independent siblings can run concurrently. All bridge layers require success
and disable tolerated failures and caller pipeline-variable forwarding.
Only fixed mode fields and compiler artifact identities cross the graph edge.

Each node config pipeline uses the existing uniquely named `Freeze release
inputs` job, then `Route frozen candidate`, its config child and the direct
Stage/tool native bridge. This deliberately preserves the existing producer
job names and artifact contracts. A node cannot select compilation again, so
config -> config node -> Stage/tool does not create a recursive executor loop.

The node acquires the exact compiler artifact by successful job ID and byte
hash, verifies its own active native graph edge and compiler -> graph lineage,
then resolves each successful predecessor graph -> config node -> route child
-> Stage/tool edge. Existing discovery rejects failed, erased, moved, retried,
ambiguous, tolerated or incomplete producer resources, outgoing leaf triggers,
changed artifacts and wrong source/executor inputs. It binds actual immutable
predecessor output references, not mutable latest-success lookups.

Immediately before publication, a graph-specific guard reacquires the parent
lineage as well as the ordinary discovery/route checks. A retried graph-parent
bridge during result acquisition cannot escape leaf-only race checks. The
node then retains the ordinary expectations, discovery evidence, candidate
route and exact input receipt before the native candidate can start.

A failed predecessor cannot admit descendants. GitLab owns status propagation;
there is no polling loop, retry API, orphan build launcher or global queue in
the compiler. Ambiguous/failed work remains a native failed pipeline. A retry
requires deliberate existing CI/operator recovery; do not replay the entire
release to manufacture missing receipts or retry an unknown host operation.

## Final graph acceptance

The generated `Accept release graph` job depends on every rebuilt node. Green
bridges alone are insufficient. It reacquires all native producer/input/result
resources, reconstructs every selected member's expected bases from the graph's
seed pins plus its actual predecessor outputs, and verifies the original frozen
closure was changed only at that member's declared base slots.

The existing assembler independently verifies the exact executor job/receipt,
all rebuilt member outputs, unique producers, paired normal/debug images,
source/compatibility/root identities and changed resources across acquisition.
Final graph lineage and original compiler bytes are read again. The job then
fsyncs and reopens `release-graph-acceptance/receipt.json`, retained on success.
It includes the complete original graph, the assembled rebuilt subset and
explicit unbuilt consumer decisions. It is not an accepted complete release
including reused artifacts, an image existence/ISA/ABI certificate, an alias
promotion receipt or a host acceptance record.

## Source, access and rollback boundaries

Compilation requires the actual clean `main` checkout at the graph's config
source. Native config/Stage/tool targets use their existing `main` routes;
if a branch moves away from the frozen source, the checkout/source contract
fails closed rather than silently changing the release. This interface does
not create tags or change refs. Do not compile from an uninstalled feature
branch and expect it to execute as `main`.

Artifact acquisition uses only fixed allowlisted GitLab GETs through existing
`glab` authentication. Production runner job-token access and all required
registry/private module/runner-local resources must be separately admitted;
no user token is injected to make an inaccessible CI boundary look successful.
Stage 3 trust policy is source-checked before graph publication and again by
the ordinary input publisher. No private identity bytes enter the graph.

Graph and node mode fields, including partial, false and whitespace values,
suppress ordinary executor build and deployment jobs. Test-stage selection
checks reject conflicting modes. Existing nonpublishing status fixtures reject
graph fields as conflicts and cannot launch an executing graph. Default human
and ordinary managed-delivery interfaces remain unchanged without graph fields.

Rollback omits graph fields and uses the existing exact input/discovery/route
interfaces. Preserve all published inputs/results/receipts and prior digests;
never relabel old outputs, erase useful failure evidence, promote aliases or
rebuild an old release from mutable source to approximate rollback.

Offline tests exercise actual CLI acquisition with fake glab, all architecture
selections, sibling dependency fanout, explicit reuse, Stage 3 placement,
malformed modes, source/resource/lineage failures, digest-named results,
readback/no-clobber and parent/result races. Real GitLab merged-YAML dry runs
validate default isolation, whitespace guards, root/node source admission,
fixture conflicts and generated child job/needs/trigger syntax without creating
pipelines. These are not real candidate build/resource/host acceptance.

## Nonpublishing nested topology exercise

After this source is installed at `main`, the existing status fixture also
accepts `NEST_DAG_FIXTURE=nested-stage1-pass` or `nested-stage1-fail` from API
or web pipelines. Do not combine it with any build, route, bootstrap, graph,
host or executor selector. False and whitespace conflict values also refuse.
Only the selection check, nested compiler and required artifact-backed bridge
are selected; ordinary tests, executor builds and deployments are suppressed.

The compiler retains and reopens `nested-dag-fixture/child.yml` and a receipt
bound to its actual checkout, pipeline, job and child bytes. Its config child
contains one required native config bridge, forwarding only the fixed
`node-stage1-pass` or `node-stage1-fail` fixture mode. That config pipeline
compiles a second artifact-backed route child containing one native Stage 1
bridge with the existing `RELEASE_DAG=true`, `RELEASE_VALIDATE_ONLY=true` and
exact pass/fail fixture outcome. Node modes accept native downstream source
only, so the nesting terminates rather than compiling another graph root.
Every bridge uses `strategy: mirror`, forbids tolerated failure and disables
caller pipeline-variable forwarding. No API launcher or retry loop is used.

Read back the root -> child -> config node -> route child -> Stage 1 leaf
resources and both compiler artifacts. Passing requires successful status at
every layer. The failing fixture deliberately fails its Stage 1 leaf and must
fail every bridge and root, with no builds, publications or host actions.
Retain that intentional failed pipeline as test evidence, not a broken release
or a reason to retry the leaf. A successful pipeline creation is not acceptance.

This is a bounded topology/status exercise using the same bridge depth as the
native graph. It does not execute the production graph's input discovery,
lineage guards, candidate jobs, executor bootstrap, resource access or ISA/ABI
checks, and must not be presented as those contracts' live acceptance. It
does not replace the remaining full program or separately approved host canary.
