# Joyride private TEST deployment

Joyride uses the ordinary Eyrie application boundary: personal application CI
builds an image, and Nest pins an immutable image and supplies managed runtime
credentials, storage, PostgreSQL, TLS, private access, backups and monitoring.
The custom artifact importer and TEST delivery controller are retired. Do not
restore their CronJobs, Kubernetes patch authority, journal, verifier credential
or scripts as a release prerequisite.

For an application release, inspect its ordinary CI result and image digest,
change `joyride_image` in `data/kubernetes/app/joyride/test.yaml` through the
normal reviewed Nest MR workflow, then run:

    bolt plan run nest::eyrie::deploy_joyride_test

Verify the actual deployed image, completed rollout, application readiness,
sessions, private-data authorization, basemap range responses and supplied
frontend. A ready Deployment alone is not application acceptance. Keep the
previous image digest available for an explicit reviewed rollback; assess
schema compatibility before rolling application code back.

The current pin is unchanged by the controller removal. No frontend bytes,
app/database/PVC, private listener, backup or monitoring resources are removed.
The delivery token is no longer supplied. Application-side delivery endpoints,
signed receipts and publishers still need cleanup in the personal repository;
Luna's ordinary independent update path remains unfinished until exercised by
Luna. The removed queue is not an operational update path.

Before live retirement, stop new controller/importer schedules and allow their
active Jobs to finish. Confirm that the delivery journal has no active operation
and inspect application pending/running delivery counts. Preserve historical
outcomes and do not delete app data. After managed deployment, verify the exact
retired CronJobs, RBAC, scripts ConfigMap and verifier Secret are absent, while
TEST/public endpoints, private access, storage, backup and monitoring still work.

This is TEST only. Stripe and routine mail remain disabled. Production member
platform activation, payments, member communications and content publication
retain their separate owner gates. The existing approved public informational
site and www redirect must not be redeployed for this cleanup.
