# GitLab critical security rollout — preflight

Request: ^2093 (`ar-20261022-192720-ba8979`), task `t_4e366cb9`.
Status: discovery complete enough to start the required custom Workhorse source phase. No instance or runner upgrade has been applied. This document is a preflight record, not a rollout completion claim.

## Official release selection

- Official critical advisory, October 21: https://docs.gitlab.com/releases/patches/patch-release-gitlab-19-5-1-released/
- CVE-2026-110264: CVSS 10.0, unauthenticated arbitrary code execution through integer overflow compiling specially crafted regular expressions. Affected ranges: 7.0 before 18.11.13, 19.0 before 19.0.10, 19.1 before 19.1.9, 19.2 before 19.2.9, 19.3 before 19.3.6, 19.4 before 19.4.3, 19.5 before 19.5.1. Both CE and EE are affected.
- Previous advisory also affects the installed version: https://docs.gitlab.com/releases/patches/patch-release-gitlab-19-4-2-released/ (CVE-2026-97229, CVSS 10.0; fixed in 19.4.2).
- Select GitLab CE 19.4.3, the smallest supported patch within the installed minor, for all three instances. No new required minor-version stop intervenes between 19.4.1 and 19.4.3. Upgrade-path source: https://docs.gitlab.com/update/upgrade_paths/ . The advisory explicitly lists regular and post-deploy migrations for 19.4.3.
- Official index https://charts.gitlab.io/index.yaml maps chart 10.4.3 to app v19.4.3. Package: https://gitlab-charts.s3.amazonaws.com/gitlab-10.4.3.tgz . Index-declared SHA256: `f60647c423ddc80c7ea3d5ac61955bb26399faf1fc685649fdca45c5b3c251dc`. This has not yet been independently compared against downloaded package bytes.
- Workhorse must be rebuilt from `registry.gitlab.com/gitlab-org/build/cng/gitlab-workhorse-ce:v19.4.3` through `nest/forks/gitlab-workhorse`, then published to both managed registries. No target custom-image digest verified yet.
- Hawk requires the independent `nest/forks/gitlab` Omnibus image `19.4.3-ce.0`. Upstream main still pins 19.3.2-ce.0 despite the installed 19.4.1 image; reconcile source during its required repository phase, not through another variable-only build override.

## Installed inventory

| Target | Shape / architecture | Before | Selected target |
| --- | --- | --- | --- |
| Eyrie TEST | Helm, namespace test | chart 10.4.1, CE 19.4.1 | chart 10.4.3, CE 19.4.3 |
| Eyrie production | Helm, namespace default | chart 10.4.1, CE 19.4.1 | chart 10.4.3, CE 19.4.3 |
| Hawk | root-owned Podman Omnibus, arm64, gitlab.puppet, SSH port 2222 | registry.eyrie/nest/forks/gitlab:19.4.1-ce.0; Rails 19.4.1 | custom 19.4.3-ce.0 |
| Owl | root Podman runner, amd64 | 19.3.2 / 23a5dafc | pending release/artifact selection |
| Falcon | root Podman runner, amd64 | 19.3.2 / 23a5dafc | pending release/artifact selection |
| Hawk | root Podman runner, arm64 | 19.3.2 / 23a5dafc | pending release/artifact selection |
| Runner1 | root Podman runner, arm64 | 19.3.2 / 23a5dafc | pending release/artifact selection |
| Builder1 | root Podman runner, arm64 | 19.3.2 / 23a5dafc | pending release/artifact selection |
| Builder2 | root Podman runner, arm64 | 19.3.2 / 23a5dafc | pending release/artifact selection |
| Builder3 | root Podman runner, arm64 | 19.3.2 / 23a5dafc | pending release/artifact selection |
| Kestrel | root Podman runner, riscv64 | 19.3.2 / 23a5dafc | pending release/artifact selection |

All listed runner versions were executed inside the actual installed containers using inventory-backed Bolt, rather than inferred from Puppet source. No runner-named Kubernetes pod was found; the managed GitLab chart disables runner installation.

Production runner IDs: Falcon 93 (paused), 95, 96, 118; Runner1 101; Builder1 104, 119; Builder2 105; Builder3 106; Kestrel 107; Hawk 122 (paused); Owl 125, 126, 127 (Owl Joyride). All nonpaused production records returned online. Preserve all IDs, admission states and registrations. TEST API currently lists stale copies of production runner IDs 93 through 126, not an online runner1-test record; do not count those restored records as separate active managers or silently register replacements.

Official Runner discovery: https://gitlab.com/api/v4/projects/gitlab-org%2Fgitlab-runner/repository/tags?per_page=10 reports v19.5.1, v19.5.0, v19.4.1, v19.4.0, v19.3.3 among recent tags. https://gitlab.com/gitlab-org/gitlab-runner/-/raw/v19.5.1/CHANGELOG.md lists Go 1.26.10 and base images 0.0.58 maintenance updates. https://gitlab.com/gitlab-org/gitlab-runner/-/raw/19-4-stable/CHANGELOG.md lists 19.4.1 as latest in that branch. Do not assume Runner shares server patch numbering or that the Rails CVE directly affects Runner. https://docs.gitlab.com/runner/#gitlab-runner-versions recommends matching major/minor, while documenting backward compatibility across minor updates. Final Runner target and all required helper architecture manifests still need verification.

## Migration and backup evidence

- Corrected Rails preflight succeeded independently on TEST, production and Hawk: `version=19.4.1`, `pending_batched=0`, `pending_schema=false`. Query: batched statuses other than finished/finalized [3,6]; schema via `ActiveRecord::Base.connection_pool.migration_context.needs_migration?`.
- Initial query using `connection.migration_context` was incompatible with this ActiveRecord API; corrected to `connection_pool`. No mutation was performed.
- Eyrie GitLab CNPG instances Ready (one each). Production conditions: Ready=True, ContinuousArchiving=True, LastBackupSucceeded=True. CNPG Backup CRs completed on October 22 at 02:02:20Z (production) and 02:01:58Z (TEST). Convenience status fields `lastSuccessfulBackup` and `firstRecoverabilityPoint` were absent; CR evidence and conditions were read instead.
- Production scheduled logical backup Job `gitlab-backup-29878128` succeeded; logs contain `Plan completed successfully with no result`.
- Falcon stat: `/nest/backup/gitlab/latest_gitlab_backup.tar` resolves to 6,357,882,880 bytes, mtime October 22 at 17:06:06 -0400. Saved Rails secret exists, 4,332 bytes. Secret contents were not read or logged. Asynchronous timestamps must be rechecked before deployment rather than used for freshness arithmetic.
- Hawk data mounts: `/srv/gitlab/data:/var/opt/gitlab`, `/srv/gitlab/config:/etc/gitlab`, `/srv/gitlab/logs:/var/log/gitlab`, `/srv/gitlab/gitlab.rb:/omnibus_config.rb`. Native readiness returned status ok. `/nest` is mounted from `falcon.nest:/nest` via NFS4.
- Hawk off-host backups live under `/nest/backup/hawk-gitlab`, NOT `/nest/backup/gitlab-hawk`. Existing archives include `1790654038_2026_09_29_19.4.1_gitlab_backup.tar` (8,519,680 bytes) and a 19.3.2 archive, plus gitlab-secrets.json and gitlab.rb. These are old: create and verify a current matching backup and restricted off-host secret/config copies before Hawk migration. The wrong-path first probe failed harmlessly with zsh unmatched glob; corrected discovery found the real directory.
- TEST restore CronJob is currently suspended. Preserve that state and inspect managed desired-state parity before rollout so a scheduled refresh cannot restore an old schema/secrets immediately after upgrade.
- Both Ceph clusters currently HEALTH_WARN, not HEALTH_OK. Production warning details: BlueFS DB stalled-read alerts, recent daemon and manager module crashes. TEST: stalled-read alerts and a recent crash. No integrity diagnosis has been made; correlate actual PG/storage/object-store availability before migrations. Do not demand an unrelated full storage upgrade or treat historical warnings alone as a new owner gate.

## Execution and rollback boundaries

Proceed with source-backed custom image publication, then required exact-head CI/MR/merge for Nest pins, TEST rollout and functional verification, production rollout and verification, Hawk independent backed-up rollout, and successive runner waves. Recheck essential safety gates at execution. Short outages and active work are authorized, not a reason to wait for an idle fleet.

A Helm/image rollback does not reverse database migrations. Use forward repair where safe; a restore requires a version-matched backup, matching Rails secrets and coordinated repository/database handling. Logical Eyrie backups intentionally omit registry/artifact payloads and are not a complete independent disaster-recovery copy. The TEST restore plan deletes repositories/secrets and is not authorized for production.

Still required: target OCI/helper digests, current Hawk backup, bounded baseline/after web/API and SSH/HTTPS fetch/write tests, registry pull/push checks, object-store connectivity, full migration results, source parity of suspended TEST restore, runner config/registration/secret-mount preservation and harmless real jobs across materially distinct host/executor/architecture classes. No rollout completion or broad functional health claim is made here.

## Bolt evidence

Workspace: `/home/joy/projects/.worktrees/nest-config/t_4e366cb9` with its `bolt-project.yaml`, `Puppetfile`, and `inventory.yaml`. Installed wrapper mounts this as `/modules/nest`; modulepath includes packaged Bolt modules, `/modules/nest/modules` and `/modules/nest/.modules`.

Initial `bolt inventory show owl --detail --format json` and `bolt command run 'id -un && hostname -f' --targets owl --stream` both failed before transport with `Could not find module ruby_task_helper containing task file task_helper.rb`. `bolt module install` first returned `Failed to sync modules`; rerun with `--log-level debug` successfully installed declared modules and generated types. The exact inventory and transport commands then passed with SSH user joy and output joy / owl. Installed-version checks passed on all eight hosts via Bolt. No direct SSH or ad-hoc Puppet fallback was used.

## Continuation after Workhorse publication

- Workhorse phase ^2094 completed: MR https://gitlab.joyfullee.me/nest/forks/gitlab-workhorse/-/merge_requests/1 merged at `6ef496d552e0af0d34aa9351baa66efffde99573`. Its exact-head pipeline 11304 and merged-main pipeline 11316 passed, per the retained child handoff.
- This parent independently read both Eyrie registry manifests with `podman manifest inspect`. Both expose linux/amd64 `sha256:bff2576b9f62820ff4b10459a0d47870ee63446f50653d364909949c71b253a1` and linux/arm64 `sha256:11f34da16f6d607cbf26383c17d0761bd3e7098b9d823e7a8ee0e811552bae96` for `v19.4.3`, matching the child evidence. Child-reported index digest: `sha256:de9cbb698f2cdd7e0dadd90d47af6c59b98c85505516a2cc746c7d150840beba`.
- Re-read the official October 21 advisory: 19.4.3 remains the selected smallest fixed patch, with regular and post-deploy migrations explicitly required. This is not a Runner advisory.
- Fast-forwarded the isolated Nest worktree to current `origin/main` at `0633cf8306`; no source upgrade pins or deployments have been made. `git diff --check` passed. Authenticated GitLab API identity is Talon, username `talon`, ID 19.
- Read authoritative Hawk fork CI through the GitLab API: main still pins `19.3.2-ce.0`. The canonical checkout is stale and was not edited. A separate isolated `nest/forks/gitlab` repository phase is needed to publish `19.4.3-ce.0`; it must not deploy Hawk itself.
- Found desired-state mismatch requiring inclusion in the parent source change: live TEST restore is suspended, but generic `data/kubernetes/test.yaml` sets `restore_suspended: false` and the GitLab-specific test data has no override. Preserve the current suspension explicitly in GitLab TEST data before managed deployment. Do not invoke the destructive restore plan as an upgrade check.
- Local `skopeo` is absent; `podman manifest inspect` works. Local `glab api` does not support `--jq`; use Python JSON filtering instead. These are tooling differences, not service blockers.

Next owned work remains: publish Hawk's matching image through its distinct source repository; update Nest chart/host/runner pins and TEST restore suspension through exact-head CI/MR/merge; managed TEST then production then Hawk deployments and runner waves; full bounded functional and migration verification. No installed security-update completion is claimed.

## Nest source update and refreshed safeguards

- Hawk image publication completed through `nest/forks/gitlab` MR !1, merged SHA `3fa8c8ef3ed60e6cc9802c357835a8745b258fb1`. Independently inspected `registry.eyrie/nest/forks/gitlab:19.4.3-ce.0`: amd64 `sha256:a2d31fc411c9bd1961474074a95ccf7eef99710fa34272b098b2cc5857c18376`, arm64 `sha256:28f95c63db7afb68d10ddb870f8d3d7271847d81e1aec16f73da31de1c2573a1`.
- Downloaded chart 10.4.3 and independently verified its bytes against the official index SHA256 `f60647c423ddc80c7ea3d5ac61955bb26399faf1fc685649fdca45c5b3c251dc`.
- Selected Runner 19.4.1: latest patch of the matching server minor, rather than assuming server patch numbering applies to Runner. Official version policy recommends matching major/minor. Verified upstream manager manifests for amd64, arm64 and riscv64; respective digests `sha256:e5a1b04258363fd2ce2d5f8e1aac9812ba72a07d629cdfbfe6f03f26f32c1893`, `sha256:5518baebaf97042925f9ef71fa1bcb930d72794b5a80eb1b6ee6d9175d33be79`, `sha256:656b814f301fcd327c3a6d7cdcf27fed9a1f3d47e45a485a1d00ebacd2c7609d`.
- Verified matching upstream helper tags `x86_64-v19.4.1`, `arm64-v19.4.1`, `riscv64-v19.4.1`: manifests `sha256:d3b1d8b96381721ea3ad1ca5ef5e133f0c06884edd78f3d32856839c2246a3a6`, `sha256:aa8254590841f3ee8beffa5cbf1dfd748324b75edb0f026290e861b0438e514e`, `sha256:6fbd9a77f97f3fe90b6f4f3367378b2ca50fc6b5b3b333f6f558cbb057bda652`. Installed/job verification remains required.
- Prepared only chart 10.4.3, Hawk image 19.4.3-ce.0, Runner 19.4.1 and GitLab-specific TEST restore suspension source changes. `pdk validate` passed. No new leaf-resource specs are warranted for these pin changes.
- Created Hawk native matching pre-upgrade backup `1792704043_2026_10_22_19.4.1_gitlab_backup.tar`; copied archive plus secrets/config to restricted `/nest/backup/hawk-gitlab/20261022-pre-19.4.3/`. Archive listing passed and local/off-host SHA256 values match: `be92a7e2a62bfd516ac21259ee123e99d79b5ff625b2d8ee9b4726b2de6b6c48`. Final metadata glob failed because the unprivileged shell cannot traverse the restricted directory; exact-path metadata readback follows. No secret contents were logged.
- Both Eyrie CNPG clusters remain healthy with October 22 completed physical backups. Production logical backup jobs `gitlab-backup-29878128` and `gitlab-backup-29878308` succeeded. Current logical archive is nonempty. TEST restore remains suspended. No instance or runner deployment has occurred at this checkpoint.
