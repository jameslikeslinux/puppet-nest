# Joyride private TEST deployment

Joyride uses the ordinary Eyrie application boundary: personal application CI
builds an image, and Nest pins an immutable image and supplies managed runtime
credentials, storage, PostgreSQL, TLS, private access, backups and monitoring.
Luna's self-service TEST updates retain the existing small artifact importer and
deployment adapter. These are the concrete consumer of the read-only GitLab
credential and exact-workload Kubernetes role, not the withdrawn signing,
custody, supervisor or production-attestation framework. There is no new service
or connector authentication ceremony.

For a routine frontend release, Luna pushes to `joy/joyride`, inspects its normal
check/build/PostgreSQL smoke result, and uses its existing manual `preview` job
or the private Tailscale `POST /ops/deploy` endpoint. The importer checks the
successful exact-head CI and immutable multiarchitecture digest. The adapter
changes only `test/joyride-test` images, verifies readiness and reports terminal
success/failure through status. HTTP 202 alone is not deployment success.

Luna receives no host, Bolt, Kubernetes or production authority. Her authorized
Tailscale path is authentication for its scoped listener; no connector token,
synthetic identity header or extra Tailscale-side service is needed. Ordinary CI
uses its existing scoped TEST credential, not host or infrastructure secrets.

For infrastructure deployment or a durable baseline pin, inspect ordinary app
CI and image identity, update `joyride_image` in this repository through review,
then run:

    bolt plan run nest::eyrie::deploy_joyride_test

Verify the actual deployed image, completed rollout, application readiness,
sessions, private-data authorization, basemap range responses and supplied
frontend. A ready Deployment alone is not application acceptance. Keep the
previous image digest available for an explicit reviewed rollback; assess
schema compatibility before rolling application code back.

The current pin, supplied frontend, database/PVC, private listener, backup and
monitoring remain unchanged. Only the adapter receives exact named-workload patch
authority; this change adds no Kubernetes credential to app containers or CI.
The adapter's nonsecret journal preserves interrupted-operation identity. Its
separate delivery credential cannot perform member or production operations.

Application-side signed production receipts and unused evidence publishers still
need removal in the personal repository. Retain ordinary TEST artifact checks,
queue status and idempotency. Luna's current self-service acceptance remains
unfinished until Luna herself performs a benign update and verifies its result.

Before managed activation, inspect pending/running deployment counts and existing
journal state. Do not replay old operations. After deployment, verify exact RBAC,
healthy schedules, app readiness, denied direct/public operations, private access,
storage, backups and monitoring. Preserve historical outcomes and app data.
Production promotion/rollback remains an explicit reviewed same-artifact operator
operation with Joy's publication/activation gates, not another signing service.

This is TEST only. Stripe and routine mail remain disabled. Production member
platform activation, payments, member communications and content publication
retain their separate owner gates. The existing approved public informational
site and www redirect must not be redeployed for this cleanup.
