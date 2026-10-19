# Joyride TEST artifact importer

Nest source manages `joyride-test-artifact-import`, a nonroot CronJob running
every five minutes in namespace `test`. It independently imports recent successful
project 83 CI artifacts into TEST's Artifact allowlist. Importing an artifact is
not deployment, content approval or production authorization.

The importer reads the five most recent successful pipelines, oldest first,
skips evidence already recorded, excludes legacy single-architecture builds,
and calls the application's `register_artifact` command. That command verifies
successful exact-head check/build/smoke jobs, source head, repository and digest.
A successful command must be followed by database readback. Exceptions produce
only bounded counts and failure status, never raw HTTP or credential details.
A failed candidate does not prevent checking the other candidates. Older
pipelines outside this bounded discovery window require an explicit trusted
import; they are not automatically marked eligible.

Equivalent branch/MR pipelines can produce the same digest and source head.
Before recognizing such a duplicate, the Nest importer independently checks the
candidate's successful project/pipeline identity, canonical URL, exact source,
required check/build/smoke jobs, immutable image evidence and both architectures.
It then requires an already verified database row matching BOTH digest and source.
The original pipeline receipt remains unchanged; no new row or eligibility is
manufactured. A different source, unverified row, incomplete CI or mismatched
image evidence cannot take this path. Final database readback remains mandatory.

The dedicated encrypted `nest::service::joyride::artifact_verifier_token` becomes
only `joyride-test-artifact-verifier`. Only the importer references that Secret.
Web, ops, worker, frontend, ordinary CI and Luna never receive it. The importer
has no service-account token, Kubernetes permissions, delivery token, mail
credential, private-media mount or production database. Database access is
necessarily privileged; the job runs only the pinned reviewed application image
and the Nest-managed script. Application artifacts do not supply importer code.

Deploy source through the existing declarative wrapper:

    bolt plan run nest::eyrie::deploy_joyride_test

Inspect safe counts and job conditions, not Secret contents:

    kubectl -n test get cronjob joyride-test-artifact-import
    kubectl -n test get jobs

For a bounded immediate verification, create a uniquely named Job from that
CronJob and wait for its completion. Read back Artifact rows using trusted
management access, selecting only digest, source_head, pipeline_url and
 test_passed. Do not attach database exports or rendered manifests as evidence.

The private repository documents the verifier credential's bounded expiry and
rotation. Reconcile the dedicated Secret through the same managed path after
rotation, then verify a real import before revoking the previous credential.

This component does not provide the delivery controller, CI preview credential,
Luna's single-token deployment canary, production promotion or rollback. Those
remain separate parent acceptance work. Source-managed baseline application
pins remain unchanged by artifact registration.
