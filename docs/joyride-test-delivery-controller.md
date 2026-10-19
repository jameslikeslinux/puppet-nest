# Joyride TEST delivery controller

Nest owns the adapter and the immutable interpreter image. Application releases
cannot update the controller, importer, ServiceAccount, RBAC or private listener.
This controller implements TEST only; it never claims production requests.
Production promotion remains separately owner-approved and unimplemented here.

## Boundary and recovery

The CronJob `test/joyride-test-delivery` serializes scheduled runs with `Forbid`.
Its ServiceAccount can get/patch only Deployment `joyride-test` and get/update
only ConfigMap `joyride-test-delivery-journal`. It cannot list resources, read
Secrets, exec, create workloads, reach another namespace through RBAC or delete
anything. The mounted Secret projection contains only the delivery token. No
member database, media, mail credential, artifact-verifier credential or Luna
ops token is mounted.

The fixed application delivery API supplies an already independently verified
repository@digest. The adapter rejects tags, other repositories, malformed IDs,
unknown actions and unexpected container sets. It journals before claiming,
then patches only the five existing application/init image fields and one
release annotation. UID and resourceVersion JSON Patch tests guard the write;
a full non-image Deployment spec fingerprint detects concurrent platform edits.
It preserves runtime policy, ordinary-worker scheduling, storage and secrets.

A completion requires the exact desired images/annotation, observed generation,
one updated/ready/available replica, database readiness, a working CSRF endpoint,
a current basemap manifest and a served HTML homepage. It rereads the exact
Deployment after the application probes before reporting success. This is a
bounded delivery probe, not a substitute for the browser/entitlement/payment
acceptance suite. Controller readiness alone is never success.

A journal survives interruption after claim, uncertain patch delivery or a
committed terminal callback. It resumes the same operation rather than losing
running requests or issuing a second independent release. Network errors preserve
that journal. The rollout deadline is ten minutes across invocations. An expired
or conflicting rollout is marked failed without automatic image/schema rollback.
Terminal callback recovery preserves the application's existing terminal outcome.
Logs contain only bounded status text, never response bodies or credentials.

The journal resource deliberately has no data field in the Helm baseline:
controller-owned data is not reset by ordinary three-way Helm updates. Do not
force-replace it or install a second controller. Before platform maintenance,
suspend the CronJob, wait for its active Job to finish and inspect the sanitized
journal. A platform Helm upgrade still explicitly applies the source-pinned
baseline app image; it is not an automatic frontend promotion. Reapply the
selected verified release afterward through the same request path if needed.

## Verification and live follow-through

Run the focused state-machine fixtures and repository validation:

    PYTHONDONTWRITEBYTECODE=1 python3 spec/app/joyride/test_delivery_controller.py
    pdk validate
    pdk test unit --tests=spec/files/joyride_delivery_controller_spec.rb

The fixtures test interruption, callback replay, stale generation, concurrent
platform edits, wrong repository/tag/action, namespace isolation and exact
JSON Patch scope. They are synthetic contracts, not live rollout evidence.

After reviewed source and exact-head CI pass, render and deploy only through
`nest::eyrie::deploy_joyride_test`. Inspect the current queue before enabling the
controller; retain all existing owner gates. Verify its real ServiceAccount can
patch only the named Deployment/journal and cannot read Secrets or production.
Exercise a real verified harmless TEST artifact, observe exact images and actual
application behavior, callback success and an explicit prior-digest rollback.
Check journal preservation through a normal Helm upgrade before relying on it.
Do not manually create concurrent Jobs from the CronJob during a rollout.

Only after that controller acceptance should Luna's single scoped ops token be
provisioned through an authorized secure credential intake. Never paste it in a
chat, code artifact, screenshot or task report. Her real authenticated status,
diagnostics, deployment request and CI preview canaries remain required. No
production, public content, payment or member communication approval is conferred
by this adapter or by a successful TEST release.
