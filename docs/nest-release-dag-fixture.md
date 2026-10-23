# Native release DAG status fixture

These are isolated real multi-project status edges for R07, not the complete
release DAG and not a release build. Each accepted Stage repository entry runs
its ordinary source/adapter tests and one exclusive deterministic fixture job.
Config uses GitLab `strategy: mirror`; a red child must make the parent bridge
and pipeline red. There is no `allow_failure`, detached API trigger, outgoing
Stage trigger, executor rebuild, alias promotion, or host rollout in this mode.

## Supported invocation

On a reviewed config branch or main, create an untagged web/API pipeline with
exactly `NEST_DAG_FIXTURE=pass` or `NEST_DAG_FIXTURE=fail`. These select only the
config admission job and one native Stage 0 bridge. Use `stage1-pass` or
`stage1-fail` for the equivalent Stage 1 edge, or `stage2-pass` and `stage2-fail`
for Stage 2, or `stage3-pass` and `stage3-fail` for Stage 3. Each selector runs
only its matching bridge. Every destination is
fixed in source, not caller-supplied. The fail mode intentionally
fails its downstream job; a successful parent would be a regression. It does not
inject an OS failure. Ordinary push/MR/tag pipelines never execute this bridge.
Malformed/conflicting modes fail admission and suppress all normal config jobs,
including image publication, r10k and release input freezing. Do not combine the
fixture with legacy, executor, release, runner smoke or build selectors.

Three literal release flags are forwarded: `RELEASE_DAG=true`,
`RELEASE_VALIDATE_ONLY=true`, and the selected `RELEASE_DAG_FIXTURE=pass|fail`.
Stage 3 additionally forwards the literal empty `HOSTNAME` to clear Docker's
automatic runtime hostname, which is not a release host selector. Nonempty
caller host/placement selectors are rejected by bridge rules before forwarding.
The admission job similarly removes only this runtime hostname before its CLI
check. Direct CLI calls with a nonempty HOSTNAME still refuse. No chosen host,
placement, arbitrary command or other runtime environment is forwarded.
Default and caller pipeline variables are not forwarded. The destination is the
fixed `nest/stage0`, `nest/stage1`, `nest/stage2` or `nest/stage3` main branch, never a
user-provided project/ref/command. Observe
and record its actual SHA and job identities; main is not an immutable build pin.
The config admission command is `env -u HOSTNAME python3 scripts/nest-release-dag-fixture.py`.
It accepts no arguments, performs no network or write operations, and returns
0 only for the supported operator selection, otherwise 1. Its success is not a
child execution receipt.

## Acceptance and rollback

Before live fixture submission, use GitLab dry-run lint on expanded current YAML
to check pass/fail and conflicting/source-event selections. After submission,
read both exact parent pipelines, their bridges and downstream pipelines/jobs.
Require a real successful fixture exit for pass, a real exit-1 fixture failure for
fail, and no build, publication or further bridges in either child. Read the exact
child trace to distinguish intended failure from infrastructure or test failure.
A skipped/empty child, failed trigger creation or admission failure does not prove
failure propagation. Preserve the intentionally failed pipeline as test evidence;
do not retry it into a green result.

Rollback removes the local include and fixture guard rules together. Ordinary CI
remains unchanged when the selector is absent. No release artifact, alias, host
or persistent runtime configuration is changed by fixture execution.

Remaining R06/R07 work includes the full Stage 0/1/2/3 and tool dependency graph,
noncyclic config/OpenBolt bootstrap, actual predecessor-result-to-descendant-base
binding, resource/CPU/ABI and job-token admission, complete consumer decisions and
explicit promotion/rollback. Do not fill future digests with invented values or
call these isolated status edges an end-to-end release. All disruptive host exercises
remain separately owner-gated.
