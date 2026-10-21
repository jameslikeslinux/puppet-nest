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

The supplied frontend, database/PVC, private listener, backup and monitoring
contracts remain unchanged. Only the adapter receives exact named-workload patch
authority; this change adds no Kubernetes credential to app containers or CI.
The adapter's nonsecret journal preserves interrupted-operation identity. Its
separate delivery credential cannot perform member or production operations.

Application MR 13 removes signed production receipt consumers and the unused
evidence publisher. MR 14 moves ordinary application CI to project runner 127.
Its merged-main pipeline 10866 passed check/build/smoke and published the reviewed
multiarchitecture image pinned here, installed on TEST generation 24 by preview.
The dormant production candidate pin stays aligned but its compile guard and zero
replicas remain unchanged; this does not activate production. Production delivery
is unconditionally denied, including with legacy enable variables. Historical
database records remain for non-destructive upgrades, not new admission.

The importer also discovers running pipelines, but admits one only when required
check/build/smoke and every other job succeeded and the sole pending work is the
optional preview. This prevents registration waiting on that preview's completion.
All exact project/source/pipeline/digest and architecture checks remain. Preview
waits boundedly for registration and then the terminal controller result; inspect
its retained `test-deployment.json`, not just the pipeline badge or HTTP 202.
See the personal application's `docs/delivery-status-contract.md`.

Luna already independently deployed a benign revision through pipeline 10829,
preview retry 43584. Its first preview hit the registration race. The operator's
later rollback was not Luna rollback acceptance. The changed waiting/terminal
contract and Luna's rollback still need live verification after this deployment.
Pipeline 10866 first preview 43738 failed observation during the replacement
rollout. Retry 43759 used the same idempotency key and deployment identity and
returned terminal success. Preserve both historical receipts. Application MR 15
adds bounded transport and gateway retries without changing identity or deadlines;
authorization, malformed responses and terminal failures remain fail-closed.
Merged-main pipeline 10892 passed every job on runner 127, including preview
43885, and independently reached terminal TEST success on the baseline pinned
here. Billing remains disabled and routine mail off. Checkout binding and
authoritative reconciliation hardening passed application tests; actual sandbox
payment, waiver and member-access acceptance are still original-owner work.
Use the verified actual pre-preview artifact for rollback, not the older delivery
row's previous_digest: managed deployments and that history can differ.

Current cleanup inventory (readback before this rollout):

- Removed from Nest source: signing/custody/supervisor collection and admission
  framework. Owl reports its supervisor inactive with no loaded supervisor unit;
  the checked evidence state/configuration directories are absent.
- Removed from application source and installed TEST: signing consumer/tools/
  publisher and custom production admission in MR 13. Preserve historical audit rows.
- Kept: DB/media, TLS, encrypted runtime/provider/pull/read-only verifier secrets,
  private Tailscale listener, ordinary health/backup/restore and the small TEST
  importer/adapter needed by Luna's self-service. Public informational stays put.
- Kept: ordinary project runner 127 and its unprivileged engine, the concrete
  consumer for Luna's check/build/publish/preview without host-root/eyaml access.
  All pipeline 10866 jobs ran on it, including terminal preview. Project 83 now
  disables shared and group runners; independent readback lists only runner 127.
  Shared Nest runners are unchanged. Dedicated unused credential scope revocation
  completed in private MR 13 after source/live consumer checks: only the two
  dedicated evidence registry readers were revoked. Necessary application,
  provider, pull, verifier, delivery and runner credentials remain.

Before managed activation, inspect pending/running deployment counts and existing
journal state. Do not replay old operations. After deployment, verify exact RBAC,
healthy schedules, app readiness, denied direct/public operations, private access,
storage, backups and monitoring. Preserve historical outcomes and app data.
Production promotion/rollback remains an explicit reviewed same-artifact operator
operation with Joy's publication/activation gates, not another signing service.

This is TEST only. Joy has authorized sandbox billing using the exact TEST price
price_1USr7ARxm5b9CJTLAsfCS7RO. Runtime billing remains disabled until encrypted
provisioning, the exact webhook transport and application/frontend integration
are verified; this pin reconciliation does not enable it. Routine mail stays off.
Private MR 13 supplies the recoverable encrypted sandbox key pair. The TEST
runtime Secret now projects the existing STRIPE_SECRET_KEY and
STRIPE_PUBLISHABLE_KEY contract, rejecting non-sandbox prefixes. The official CLI listener signing secret is now encrypted in private MR 14,
with independent merged-source recovery verified. Never invent a signing secret or
register the unreachable private .eyrie URL. Stripe documents its outbound CLI
listener as an option for private testing without a public gateway; that is not
proof of registered public-endpoint delivery or production readiness.
Production member platform activation, payments, member communications and content
publication retain their separate owner gates. The existing approved public
informational site and www redirect must not be redeployed for this cleanup.

The TEST-only outbound listener uses the official Stripe CLI 1.54.1 pinned to
its independently inspected multiarchitecture index. It refuses live key prefixes
and compares the provider's actual device-specific signing secret with managed
configuration before forwarding. It has no Service, ingress, Kubernetes token or
RBAC. Only the sandbox API key enters the forwarding process; raw CLI output is
suppressed because startup prints the signing secret. Billing remains disabled
until transport verification; process readiness is not provider acceptance.
Forwarding targets the internal web Service with the exact allowed Host header,
not an unreachable public registration. This does not prove production delivery.

Luna's updated independent canary and rollback have now passed. Her comment-only
source b530be153c8292701365676133e80a9097ab6765 passed pipeline 10895, including
terminal preview 43899, entirely on runner 127. Independently read application
state confirms forward deployment 941104ca-f6ee-440d-b136-010e26688cb3 succeeded
on sha256:65bc1b91949e727edf0f9d66a649405cb3aa52c3810c79f85e55da87a5bedfa4,
then her scoped rollback 579c6106-332a-4812-80b2-08e0dd930ca3 succeeded on the
reviewed c5786b2b baseline. Actual Kubernetes images again match that baseline.
Historical preview failures remain failures, not overwritten successes. No
production, billing or routine-mail authority was added by this canary.
