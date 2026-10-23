# Separate config orchestration and executor source identities

Release expectations schema 2 is an explicit, opt-in extension of schema 1.
It uses the same fields; the version changes the meaning of their source
relationship, not the literal identity or provenance of either snapshot.

- `sources["nest/config"]` is the exact config checkout publishing inputs and
  compiling the graph. Its input jobs, native config pipelines, graph artifacts,
  public identity trust policy and final graph lineage must match that SHA.
- `executor.source` is the exact config checkout used to build the selected
  executor image. Its independently acquired successful build job, receipt,
  installed source, module inventory and immutable image must match that SHA.
  The actual Bolt build plans and Puppet modules come from this executor, not
  from a newer graph publisher. Schema 2 does not install newer build recipes
  into an old image or claim equivalence between different module inventories.
- Stage/tool source entries still bind their own producer checkouts. Every
  source, version, member, consumer decision and executor image remains part of
  the frozen expectations digest and retained result/manifest closure.

Schema 1 still requires `executor.source == sources["nest/config"]`. Existing
records retain their original bytes, digests and interpretation; never upgrade
or relabel a historical result. Unsupported versions, booleans, noninteger
versions and malformed executor SHAs refuse. Schema 2 may also use identical
sources; choosing version 2 still changes the frozen digest.

## Acquisition and bootstrap

The binder and assembler acquire the executor build at `executor.source`, while
input jobs and native config lineage remain at `sources["nest/config"]`. Both
sources are rechecked across acquisition with the existing fixed GET paths.
Predecessors must use the same schema, source closure, release and executor;
a self-consistent result from a different executor or schema cannot be rebound.
Architecture, source/module observation, exact resource identities, erased or
failed jobs, immutable image references and race refusals are not relaxed.

An OpenBolt bootstrap may therefore retain three identities: its old config
input publisher, its old executor build, and the successor executor build.
The successor must differ from both old identities. The original OpenBolt
expectations and result bytes are preserved and independently checked; a
successor is never its own prerequisite.

## Compatibility and rollout

This source implements config-side validation, binding, routing, assembly,
graph freezing/acceptance and bootstrap for schema 2. The executing graph CLI
remains disabled. Offline synthetic graph fixtures are not native scheduling,
job-token, resource, hardware or live acceptance evidence.

An immutable executor built before this support was added still has its original
schema-1-only validator. It cannot execute schema-2 records merely because the
publisher understands them. A schema-2-capable executor must first be built,
source/receipt/module/image verified and admitted by each selected Stage/tool
consumer through its repository-owned source boundary. Specialized consumers
must preserve their exact admitted executor tuples and old rollback paths;
there is no wildcard, latest-success selection or source-check bypass here.
Consumers must independently verify the input publisher at the config source
and the executor at its separately pinned build source. Until that work and
nonpublishing live graph contracts pass, use the existing schema-1 interfaces.

After that prerequisite, later unrelated config policy commits need not force
another executor build. If the actual executable build plans/modules need to
change, build and verify a new executor normally. A changed orchestration source
is not proof that an older executor contains that change. No candidate rebuild,
alias promotion or host operation is authorized by selecting schema 2.

Rollback omits the opt-in version and continues using untouched schema-1
inputs with their exact original executors and receipts. Retain both generations;
do not rewrite records or change aliases to approximate a rollback.

## Verification

`python3 spec/files/nest_release_source_contract_test.py` exercises the real
validators and acquisition/graph/bootstrap implementations against explicitly
synthetic offline native-resource fixtures. It covers preserved schema-1
refusal, schema-2 literal source validation and digest binding, separate input
and executor jobs, mismatched predecessor closure, receipt/module/image/job
failures, compiler/freezer projection, final graph acceptance and three-source
bootstrap. It does not build images, create GitLab pipelines or operate hosts.
