# Native release DAG status fixture

This is the first real multi-project status edge for R07, not the complete release
DAG and not a release build. The Stage 0 repository's accepted native entry runs
its ordinary source/adapter tests and one exclusive deterministic fixture job.
Config uses GitLab `strategy: mirror`; a red child must make the parent bridge
and pipeline red. There is no `allow_failure`, detached API trigger, outgoing
Stage 0 trigger, executor rebuild, alias promotion, or host rollout in this mode.

## Supported invocation

On a reviewed config branch or main, create an untagged web/API pipeline with
exactly `NEST_DAG_FIXTURE=pass` or `NEST_DAG_FIXTURE=fail`. These select only the
config admission job and one native Stage 0 bridge. The fail mode intentionally
fails its downstream job; a successful parent would be a regression. It does not
inject an OS failure. Ordinary push/MR/tag pipelines never execute this bridge.
Malformed/conflicting modes fail admission and suppress all normal config jobs,
including image publication, r10k and release input freezing. Do not combine the
fixture with legacy, executor, release, runner smoke or build selectors.

Only three literal variables are forwarded: `RELEASE_DAG=true`,
`RELEASE_VALIDATE_ONLY=true`, and the selected `RELEASE_DAG_FIXTURE=pass|fail`.
Default and caller pipeline variables are not forwarded. The destination is the
fixed `nest/stage0` main branch, never a user-provided project/ref/command. Observe
and record its actual SHA and job identities; main is not an immutable build pin.
The config admission command is `python3 scripts/nest-release-dag-fixture.py`.
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
call this single status edge an end-to-end release. All disruptive host exercises
remain separately owner-gated.
