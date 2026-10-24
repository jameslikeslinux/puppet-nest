# Read-only host update wave planning

`nest::host::update` accepts optional `mode=plan` and `policy`. This computes
failure-domain waves from exact inventory names on the Bolt supervisor. It does
not contact target hosts, run reset/update/Puppet, inspect transaction state,
reboot, record acceptance or authorize any of those operations. Inventory
resolution can contact PuppetDB. The default `mode=legacy` remains unchanged,
including its explicit `reboot=false` default and fail-closed preparation.

Pass a private JSON parameter file to avoid shell/JSON quoting mistakes:

```sh
bolt plan run nest::host::update --params @/absolute/path/wave-plan-params.json
```

The parameter document contains `targets`, `mode: "plan"` and `policy` as
specified below. Retain and inspect the returned JSON. `reboot=true`,
`reset=false`, a missing policy, or a policy supplied to legacy execution
refuses before any host command. There is no transactional prepare/reboot mode
in this interface yet. Never change mode to legacy to execute a computed wave:
legacy execution does not enforce this policy, release or transaction identity.

## Policy schema 1

The policy has exactly these fields; unknown fields refuse:

- `schema`: integer 1; `kind`: `nest_update_wave_policy`.
- `release`: exact `sha256:` plus 64 lowercase hexadecimal digits, identifying
  the reviewed release manifest, not a mutable alias or a build name.
- `config_source`: exact 40-character lowercase Git SHA selected for subsequent
  ordinary main catalogs. This is an expectation, not served-source proof.
- `max_parallel`: integer from 1 through 4. This is a conservative upper bound,
  not permission to disrupt that many hosts or an assertion of available quorum.
- `domains`: nonempty unique array of serial failure-domain tokens.
- `hosts`: ordered nonempty array of exact `name`, `platform`, `kernel` and
  `domains`. Each name is an inventory name, not an SSH URI; platform is an
  explicit token; kernel is an exact release string. Qualified kernel exceptions
  are selected explicitly per host. Each membership array is nonempty, unique,
  and references declared domains. Every declared domain must be used.
- `excluded`: unique array of excluded inventory names, possibly empty. No
  excluded host may occur in the host scope or resolved targets. Recovery
  console names ending in `-console` (also before a DNS suffix) always refuse
  as targets, even if a submitted policy omits them from exclusions.
- `canaries`: nonempty unique array of selected host names, in the same order as
  the prefix of `hosts`. Each canary gets its own initial wave. Select the actual
  required hardware/service classes; a token alone is not canary acceptance.

Tokens start with a lowercase alphanumeric and then contain lowercase
alphanumeric, underscore, dot or hyphen, at most 128 characters. Host/domain
arrays are bounded to 128 entries. Exact kernel release strings additionally
allow uppercase, plus and hyphen. The complete stdin document is bounded to
256 KiB; duplicate JSON keys refuse. Task metadata keys beginning with `_` are
not interpreted as policy, approval or release identity.

The resolved inventory target set must equal the complete policy host set.
Missing/extra targets, duplicates, a broad selector that includes an excluded
host, and unknown domain names all refuse. To select a smaller scope, deliberately
freeze a new complete policy; the planner never silently drops required hosts or
canaries. Inventory response order does not change policy scheduling.

## Failure domains and ordering

Every shared domain permits at most one member in a wave. Declare actual
controller/quorum, storage and shared physical/power/USB dependencies explicitly.
If core/controller/storage operations must be serial across categories, give
those hosts a common serial domain as well as their specific domains. A host can
belong to several domains; shared physical coupling must not be lost merely
because two hosts have different service roles. Independent hosts need distinct
memberships, not a single ceremonial fleet-wide domain.

After the isolated canaries, the deterministic scheduler scans remaining hosts
in policy order, admitting up to `max_parallel` hosts with disjoint domains.
Conflicting hosts remain for later waves. Thus genuinely independent work can
proceed together rather than serializing the entire fleet. Waves are sequential
barriers in the plan, not a background scheduler or actual running workers.

The policy's topology is supplied by the engineering/release owner. The helper
cannot discover unrecorded physical dependencies or verify live quorum, capacity,
survivor readiness, disruption windows, backup freshness, recovery access or
source compatibility. Incomplete topology can yield an unsafe hypothetical plan;
review and operational admission remain mandatory. Do not submit a fictitious
fixture topology as a production scope. Tests use only explicitly fictitious
names and perform no host operations.

## Result and execution boundary

The schema-1 `nest_update_wave_plan` contains ordered `waves`, exact host policy,
exclusions, canaries, host count, maximum concurrency, release/source expectations
and a bare `policy_sha256` binding the complete canonical policy. Canonical bytes
are ASCII JSON with sorted keys, compact separators, no nonfinite numbers and a
trailing newline. This is a content identity, not a signature or owner approval.
A successful result means only that this complete metadata reconciles and can
be scheduled under its declared domains.

`topology_verified`, `release_binding_verified`, `preparation_observed`,
`execution_authorized` and `acceptance_recorded` stay false; `reboot_eligible`
is always empty. Planning success cannot put a failed or unknown preparation
into a reboot set. The task supports noop because it is always read-only.
Task failure returns a bounded generic error without echoing private input.
No file, lock, directory, service, host command or transport fallback is created.

R05/R08/R12 integration remains incomplete: transaction-owned prepare/status,
immutable generation transfer/sealing, capacity admission, verified prepared-only
reboot eligibility, boot-ID continuity after ambiguous disconnect, readiness gates,
accept/finalize and retained lifecycle reports must consume the same bound policy
before execution can be enabled. Shared state on the running host is not proof
of A/B continuity. A scope/window, rollback/retention and newly disruptive canary
approval remain separate from this scheduling-only policy. No whole release or
live lifecycle completion is inferred from these fixtures.

Rollback stops supplying `mode=plan` and `policy`; it preserves all existing
reports and transactions. It does not authorize falling back to unbound legacy
reset, replacing a prepared release or replaying an ambiguous phase.
