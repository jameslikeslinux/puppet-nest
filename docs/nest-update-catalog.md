# Normal main catalog and unchanged repeat

`nest::host::update_catalog target=HOST` executes the existing managed Puppet
wrapper on exactly one inventory-backed Linux host, using ordinary Bolt root
escalation. This is a mutating operation, not an observation, noop, tagged
package installation, offline build or replacement deployment mechanism.
Do not invoke it merely to verify that its source has been installed.

The plan requests the complete `main` environment with noop, cached-catalog
reuse and cache-on-failure disabled, and with both tag filters empty. It
supplies no build or kernel-only fact override. Existing native agent/service
coordination, platform handling and per-run lock remain in the managed wrapper.
It does not weaken transport, change credentials, retry a failed catalog,
reset/reboot, clear failed units or record transaction acceptance.

The first apply must return the actual detailed native exit 0 or 2 before a
second apply is attempted. Only repeat exit 0 is converged. A repeat exit 2
still means changes and fails convergence; exits 1, 4, 6 and unexpected codes
remain failures, never success. Missing exits, including a caught transport
error, are null and cannot pass. There is no third apply or loop. A plan can
return successfully with `result: fail`; inspect the returned outcome, not just
Bolt's exit. A transport fault with unknown completion must be inspected before
an operator reruns this mutating plan.

The result is schema 1, kind `nest_update_catalog`, containing `main_exit`,
`repeat_exit`, `repeat_attempted`, `converged`, `requested_environment: main`,
`served_source_verified: false` and `acceptance_recorded: false`. Raw catalog
logs are not copied into this returned document. Normal Bolt logs may contain
private catalog output; do not attach those without reviewing them.

## Coverage boundaries

This plan establishes native apply/repeat exits for requests to main. It does
not prove the exact source of the catalog actually served, stable boot identity,
expected transaction/release, or that two catalogs have the same source. An
unchanged repeat is not an assertion that unrelated writers could not act
between runs: the existing lock is held per apply, not across the pair. It does
not bound the duration of a full Puppet run or add timeout/kill semantics that
might leave a partially applied catalog.

Later lifecycle integration must bind real served report/source identities and
both catalog results to the expected host/boot, release and real preparation,
retain sanitized artifacts, and collect the remaining service/hardware gates
before acceptance. A configured main request is not exact-main source proof.
This interface is intentionally not composed into the read-only
`nest::host::update_health` plan; doing so would silently turn observation into
host mutation. No live full catalog was applied to test this interface.

## Wrapper compatibility and rollback

Ordinary `nest::puppet::run` callers still receive the historical wrapper mapping
of native 0 and 2 to process success. The explicit environment selection
`PUPPET_PRESERVE_DETAILED_EXIT=true` preserves the actual native exit instead;
false or unset keeps compatibility. Invalid selections refuse before service or
lock commands. Callers choosing the opt-in must handle 2 themselves instead of
mistaking it for failed transport or an unchanged run.

Regression tests exercise the actual shell wrapper with fake native commands
and the actual Puppet plan with Bolt's mock executor. They include applied versus
unchanged results, failed resources, unknown exits, failed transport, early
multi-target refusal and no implicit third attempt. No real agent, service,
dataset, host build or reboot is used by those tests. Rollback stops invoking
the new plan and omits the environment opt-in; it cannot undo resources changed
by a real catalog or authorize replaying an ambiguous apply.
