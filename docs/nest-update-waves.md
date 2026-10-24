# Read-only host update wave planning

`nest::host::update` accepts optional `mode=plan` and `policy`. Planning computes
failure-domain waves from exact inventory names on the Bolt supervisor. It does
not contact target hosts, run reset/update/Puppet, inspect transaction state,
reboot, record acceptance or authorize any of those operations. Inventory
resolution can contact PuppetDB. The default remains `mode=legacy`,
including its explicit `reboot=false` default and fail-closed preparation.

Recovery console names ending in `-console` (also before a DNS suffix) are
excluded from every mode, including legacy reset and package updates. Legacy
execution resolves inventory once and rejects the entire selection before any
host command if it contains a console; it never silently filters one out and
updates the remaining hosts. Subsequent legacy actions use that resolved target
set. Transactional modes enforce the same exclusion in their bound wave policy.
This name-based floor cannot identify a console hidden behind an unrelated
inventory alias; inventory names and explicit exclusions still require review.

Pass a private JSON parameter file to avoid shell/JSON quoting mistakes:

```sh
bolt plan run nest::host::update --params @/absolute/path/wave-plan-params.json
```

The parameter document contains `targets`, `mode: "plan"` and `policy` as
specified below. Retain and inspect the returned JSON. `reboot=true`,
`reset=false`, a missing policy, or a policy supplied to legacy execution
refuses before any host command. The separate explicit `mode=prepare` described
below invokes native transactions but never reboots. Never change mode to legacy to execute a computed wave:
legacy execution does not enforce this policy, release or transaction identity.

## Policy schemas 1, 2 and 3

The policy has exactly these fields; unknown fields refuse:

- `schema`: integer 1, 2 or 3; `kind`: `nest_update_wave_policy`.
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

Schemas 2 and 3 additionally require exactly one `preparation_window` object, with
exactly `not_before` and `not_after`. Both values use real UTC calendar timestamps
in the strict spelling `YYYY-MM-DDTHH:MM:SSZ`, without fractional seconds, offsets
or leap seconds. The end must be later than the start and at most 24 hours later.
The entire window is included in `policy_sha256`; changing it creates a different
policy identity. There is no default or automatic extension.

Schemas 1 and 2 remain supported for planning and stored-status observation, with
their original digests and output. Neither admits transactional preparation.
Planning and observation remain available before or after the window;
they validate the window structurally but never turn its presence into approval.
Schema-2 planner output adds `policy_schema: 2` and the exact window; its result
schema remains 1. This is a preparation-initiation window, not a general reboot,
acceptance, cleanup or maintenance authorization policy.

Schema 3 also requires `backup_requirements`, an exact map keyed by every selected
host name. Each value is an array of zero through eight checks. An explicit empty
array declares that this host has no Hermes backup prerequisite; it is not a
backup-discovery result or proof that every application is recoverable. The
release owner must review coverage, including application state hosted elsewhere.
Omitting a host, adding an unknown host or duplicating a generation check refuses.

Each check has exactly these fields:

- `kind`: `hermes`; other backup implementations are not supported by this gate.
- `target`: exact inventory name of the backup host, not a URI or selector.
- `user`: backup account, lowercase letter/underscore first, then lowercase
  alphanumeric/underscore/hyphen, at most 32 characters.
- `backup_dir`: canonical absolute path spelling on the backup host, at most
  255 characters, with alphanumeric/underscore/dot/slash/hyphen only. Root, empty
  components, traversal and trailing slash refuse. Native filesystem trust and
  permissions remain the existing verifier's responsibility.
- `checkpoint`: exact existing generation, alphanumeric first, then
  alphanumeric/underscore/dot/hyphen, at most 128 characters.
- `expected_sha256`: exact bare lowercase 64-character archive digest.
- `max_age_seconds`: integer from 1 through 604800, not a boolean or float.
- `required_profiles`: nonempty unique array of at most 128 profile names, each
  using the checkpoint token grammar.

Every field, including explicit empty arrays and profile order, is bound into
`policy_sha256`. Schema-3 planner output adds `policy_schema: 3`, the exact window
and `backup_requirements`; its result schema stays 1. Planning validates metadata
only, never opens an archive or claims it is current. See
`hermes-backup-verification.md` for the existing verification contract and limits.

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

R05/R08/R12 integration remains incomplete: live transaction status,
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

## Read-only stored transaction observation

`mode=observe` contacts the exact inventory hosts using ordinary Bolt root
escalation and runs only `nest reset status ID --format=json`. Unlike `mode=plan`,
this mode reads live host/ZFS identities; unlike `mode=prepare`, it cannot create,
resume or repair a transaction. Use it after an ambiguous prepare result or
reboot disconnect rather than replaying either operation. The installed CLI
must support the native status interface. Missing state, identity disagreement,
transport failure or malformed output refuses without fallback.

Supply the same complete `policy`, `targets`, an existing canonical supervisor
`output_dir`, and `observations`: a map keyed by every exact inventory hostname.
Each entry has exactly `transaction`, using the native ID grammar below. No
generation/capacity paths or preparation options belong in this read-only input.
`preparation`, `reboot=true` and `reset=false` refuse in observation mode. Observation
inputs supplied to any other mode also refuse. All inputs and supervisor
destinations validate before the first status command. The existing bounded
failure-domain waves are retained, with no new host service or controller.

The result is `nest_update_observation`, schema 1, with `policy_sha256` and waves
of durable sanitized report receipts. Each successful receipt has
`observation_retained=true`. The retained document adds `observation` with live
boot ID, `boot_changed`, current/next BE, `expected_target_booted` and
`cli_accepted_current_boot`. Unknown target identity remains null when no target
tree was recorded; it is not a successful boot. The CLI rechecks current/target
GUIDs and host/shared-state binding, but this is a point-in-time native
observation, not a lease or permission to reboot. The release expectation is
checked against the stored report; it is not independent served-release proof.

A valid pending/stopped transaction is retained and returned as observed, not
misrepresented as a preparation failure of this read-only command. Exported
historical reports lacking live observations cannot satisfy observation mode.
Observed boot IDs must agree with the changed flag and expected current/target
relationship. Unknown/private fields are discarded. Every content-addressed
observation is fsynced and reopened without replacing prior phase reports.
Transport/validation/publication failure stops later waves; it never triggers
reset, resume, reboot, Puppet, acceptance or finalize. Reboot eligibility remains
empty and independent acceptance remains false, even when the native CLI has an
accepted record. No live transaction is fabricated to test the interface.

## Explicit transactional preparation

`mode=prepare` is MUTATING, unlike `mode=plan`. Use only within an independently
approved exact reset scope. Source installation and a planning result are not
that authorization. The first real reset/reboot canary for the audit program
remains separately Joy-gated. This interface does not provision or transfer a
generation, relax quotas, select a release alias, reboot, apply a main catalog,
accept, finalize or clean up a boot environment.

The separate [host-local generation producer](nest-host-generations.md) can copy
an exact versioned read-only mounted publication into a preprovisioned empty
local dataset and seal it. Its default check is read-only; explicit transfer
does not authorize preparation or satisfy the native reset-capacity policy.
The update plan never invokes its transfer path automatically. Preparation now
requires the producer's exact sealed-generation policy and invokes only its
read-only `verify_only=true` path before any reset and again at host initiation.

Pass the complete retained `release_manifest` as well as the schema-3 `policy`,
`targets`, an existing canonical supervisor
`output_dir`, and `preparation`: a map keyed by every exact inventory hostname.
The supervisor first validates the entire manifest using the existing release
validator and reconciles every selected generation with its Stage 3 output.
The wave release must equal the canonical manifest digest, and its config source,
exact host scope, platform and kernel must match the selected member records.
This runs before controller maintenance, backup or generation contact. Each local
seal check also receives that same manifest. Missing manifests, validation
receipts instead of manifests, incomplete output matrices and mismatched content
or compatibility refuse without reset. Other modes refuse `release_manifest`;
planning and stored-status observation remain independent of its availability.
Metadata agreement is not independent producer/resource verification, catalog
attestation, release approval or native capacity admission.
Each entry has exactly `transaction`, `root_generation`, `capacity_policy` and
`generation_policy`. The last field is the complete exact schema-1 policy from
the [generation producer](nest-host-generations.md), not its returned report.
Its `hostname`, `release` and `destination` must equal this inventory host, the
wave release and `root_generation`, respectively. Older three-field preparation
inputs refuse; read-only planning and stored-status observation are unchanged.
The producer's installed verifier validates its full policy and local seal.
The transaction is a native CLI ID (alphanumeric first, then alphanumeric,
underscore or hyphen, at most 64 characters). Both paths are absolute canonical
path spellings on that target, not on the supervisor. Empty components, dot
components, traversal, shell text and the mutable `/nest/hosts/` alias refuse.
The generation verifier checks realpath, ownership, complete sealed content,
native dataset identity and retained producer receipts without publication
access, copying, locking or repair. All selected generations must verify before
the first reset; after maintenance/backup checks each affected generation is
verified again before final UTC admission. Any refusal stops new commands;
there is no fallback to transfer or unbound legacy reset. Full-content reads may
be significant I/O. This observation is not a lease, A/B continuity proof or
reset-capacity admission; the native CLI still rechecks its own identity, shared
state and capacity contracts before mutation.
The exact canonical preparation map also has a separate `inputs_sha256`, checked
again at final admission even if native argv is unchanged. It binds all supplied
generation-policy bytes; it is not a signature or authorization.
Inventory names must equal the actual native report hostname; aliases are not
silently translated. Each host may use its own explicit generation and policy.

Preparation invokes the existing `nest::app::hermes::backup` plan with only the
declared fields (minus `kind`) and `verify_only=true`. All declared generations
must verify before any native reset starts. After controller admission it repeats
the affected host's checks immediately before the final window admission and
native command. Missing, changed, stale, future-dated, busy or unreadable backups
stop preparation without capture, initialization, pruning, cleanup or restore.
No failure triggers a fallback or a new checkpoint. An unrelated host with an
explicit empty list requires no backup-host contact at its initiation.

The existing helper holds a shared nonblocking retention lock while checking
full bytes and required members, and samples publication age after hashing. It
releases that lock before returning; the result is not a storage lease, restore
validation, application-consistency recheck or source-capture timestamp. Ordinary
backup retention can subsequently remove a generation. Required durable retention
through the whole release remains unfinished and must not be inferred here.
Native verifier results appear in Bolt output, not in the sanitized transaction
receipt; durable recovery-evidence retention remains a lifecycle integration task.

Preparation checks the supervisor's current UTC time at full input validation
and again immediately before each host command, after destination and controller
maintenance checks. Admission requires `not_before <= now < not_after`. Earlier
waves and readiness checks do not reserve time for later hosts. Expiration stops
new commands; already started transactions finish and their reports are retained.
The plan neither kills a native reset at the deadline nor resumes it, extends the
window or starts a later wave automatically. Use observation after ambiguity.
An ordinary, accurate supervisor clock is a prerequisite; this is not a trusted
time service, clock-rollback detector or a lease covering task/transport latency.

A schema-3 input is still not proof of Joy's approval, verified rollback or
supported generation/capacity. Scope/window and backup coverage must be reviewed
under the separate disruptive authorization before the first real canary. Full
rollback/retention and live acceptance integration remain unfinished; there is
no new cleanup or reboot path in this change. Do not attach new fields to an
older schema or fall back to legacy execution to bypass failed admission.

Before any host command, the supervisor validates the full inventory/policy/input
scope and every report destination. No missing member is silently skipped.
The native CLI must already be the installed transaction-capable safe source,
with host-local shared state, a sealed immutable local generation bound to the
release, and its supported bound capacity policy. Missing prerequisites fail
closed; no legacy reset fallback or provisioning repair is attempted here.

For each computed wave, Bolt invokes once per host:

```text
nest reset --transaction ID --release sha256:DIGEST --root-generation PATH --capacity-policy FILE --format=json
```

The command is constructed as a shell-quoted argv with inventory-backed root
escalation, not root SSH. Canaries remain isolated; members with disjoint
declared failure domains run concurrently up to the policy bound. All members
of a wave finish before the next wave. Topology still requires owner review.
`reboot=true`, `reset=false`, missing required inputs and preparation options
supplied to another mode refuse. No `--resume` or `--resume-transaction` is
generated. Repeating the same plan encounters the CLI's existing-ID refusal,
not an automatic destructive replay; inspect stored status/report instead.

After each native invocation, the existing supervisor retainer validates and
atomically reopens the sanitized CLI report bound to transaction/release/host.
Valid stopped receipts are retained before failure is raised. A failed exit,
non-prepared receipt, transport loss, malformed report or retention failure
stops later waves; independent commands already started in that wave may finish.
A lost result is ambiguous: export native stored status/report without rerunning
preparation. Raw transport and initialization errors are not invented receipts.
Destination preflight is read-only and cannot promise future space or successful
publication; host state remains authoritative if publication later fails.

Successful output is `nest_update_preparation`, schema 1, containing the exact
`policy_sha256` and ordered waves of durable report receipts. It reports only
native preparation, not current live boot selection, served-source attestation,
readiness, kernel/platform acceptance or permission to reboot. In particular,
`reboot_eligible` stays empty and `acceptance_recorded` stays false. Copy and
reopen reports on the notification host when its filesystem differs; wrapper
supervisor paths under `/modules/nest` correspond to the mounted project path.

### Controller admission

For `control1`, `control2` or `control3`, preparation additionally requires
`maintenance`, keyed by exactly the selected controller names. Each value has
exactly `survivor`, `client`, `advertisers`, `physical_domains` and `ceph_fsid`
as documented in `kubernetes-api-vip-health.md`. The target is always taken
from the resolved transaction host, never from an unbound maintenance field.
Every controller preflight must pass before any host preparation begins and is
rechecked immediately before that controller's native command. Admission failure
cannot start reset, resume, reboot or a later wave. Each controller must be alone
in its preparation wave, even if incomplete scheduling domains would otherwise
permit parallelism; unrelated independent-host waves retain bounded concurrency.

Maintenance inputs supplied to planning, observation, non-controller-only
preparation or legacy execution refuse. Read-only status observation does not
require live service readiness, so a failed maintenance gate never prevents
inspection of an existing transaction. Legacy controller updates now refuse
instead of bypassing the bound service-aware path, including qualified names
such as `control2.nest`. A mixed selection refuses as a whole before host actions.
Preparation requires the canonical inventory names `control1`, `control2` and
`control3`; qualified controller names refuse before any task or host command,
rather than silently losing maintenance admission or rewriting bound transaction
identity. Planning and stored-status observation remain read-only and do not
rewrite names. Similarly prefixed names such as `control3-extra` are not classified
as controllers. An unrelated inventory alias cannot be identified by this
name-based floor; review exact inventory scope and do not use aliases to evade
the canonical controller contract. Non-controller legacy
behavior and the explicit no-reboot default are unchanged. Preparation remains
mutating and separately authorized: these additional point-in-time checks do
not supply that authority, withdraw an advertiser, or enable transactional
reboot. All physical declarations must reflect reviewed real dependencies;
synthetic test singleton domains are not production evidence.

Rollback removes use of explicit prepare mode while retaining all native state,
prepared BEs and reports. Do not fall back to legacy execution or invent a new
transaction ID to bypass an unresolved prior transaction. The remaining lifecycle,
shared A/B continuity, generation/capacity provisioning, readiness and separately
approved live-canary work stays open; fixtures do not prove those contracts.
