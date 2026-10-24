# Kubernetes API VIP health and maintenance

The API VIP is a routing contract, separate from etcd membership. A healthy etcd
quorum does not prevent an unready API advertiser from black-holing ECMP traffic.

## Desired steady state

Eyrie's intended policy advertises `172.21.255.255/32` from Control1 and Control2. Control3 remains an
etcd voter and an API server, but is not an intended VIP advertiser. API etcd
client reads still use Control3 and Control2: advertiser selection does not
silently change the measured slow-voter endpoint policy.

`nest::kubernetes::generate_kube_vip_manifest` uses kube-vip v1.2.4's native BGP
health checking. Each advertiser checks its own strict HTTPS `/readyz`, including
etcd readiness, with the Kubernetes CA mounted read-only. It does not check the
VIP, use an insecure TLS bypass, or substitute the lighter static-Pod probe.

The check period is ten seconds, timeout three seconds and withdrawal threshold
two consecutive failures. Startup suppresses advertisement until the first
successful check; recovery re-announces automatically. Detection is not instant,
and transient client failures during detection remain possible. This is not a
promise of zero-loss failover or a replacement for planned withdrawal. A shared
backend readiness failure can withdraw every gated advertiser: do not roll the
last stable management advertiser onto this policy until backend health and
the resulting route behavior are independently certified. Preserve a tested
rollback configuration throughout that transition.

Upstream manifest generation emits the CA environment setting but omits its
volume. The small manifest integration helper supplies that public-file mount
and preserves portable YAML, including the leading colon in `:2112`. Publication
is atomic through hidden temporary files. Replaced manifests are backed up
outside kubelet's watched directory under `/root/kubernetes-manifest-backups`.

## Client route ownership

BIRD owns the client kernel routes in table 100. On networkd-managed hosts,
`ManageForeignRoutes=no` keeps networkd from deleting routes owned by BIRD or
the CNI. `KeepConfiguration=static` alone does not preserve `proto bird` routes.

The Stage 3 incident exposed a separate client-side failure, not simultaneous
withdrawal by both advertisers. At 2026-10-19 21:41:05 UTC, Owl's networkd log
recorded removal of the BIRD multipath VIP route while configuring `podman1`.
Synchronized samples showed an empty kernel route, unchanged BIRD RIB entries
and Established BGP sessions. Networkd also removed a CNI blackhole route.
BIRD restored the VIP route at 21:41:31 UTC. This explains that observed route
loss, not every earlier API/backend deadline.

[Systemd's route cleanup implementation](https://github.com/systemd/systemd/blob/v262/src/network/networkd-route.c)
documents that foreign IPv4 multipath and unreachable routes cannot be assigned
to one interface during cleanup; the supported ownership setting is
`ManageForeignRoutes=no`. Global networkd configuration requires a daemon
restart, not merely `networkctl reload`. The narrowly tagged
`bird_route_ownership` Puppet resources change this setting and notify networkd.
Apply on one host only after verifying its network configuration and recovery
path; independently verify SSH, addresses, DNS, routes and networkd afterward.
Do not restart control-plane networking in parallel or touch excluded consoles.

After application, observe normal container bridge creation with simultaneous
kernel-route, BIRD-RIB, API and networkd-log checks. Do not intentionally remove
a production route to manufacture an acceptance test. A quiet interval without
bridge creation does not exercise this regression.

## Planned maintenance

Replace or withdraw one existing advertiser at a time. The Bolt plan refuses
bulk replacement/withdrawal and requires an explicit different survivor. Before
publication/removal it checks the survivor's installed VIP manifest, strict
CA-verified API readiness and a BGP route with that survivor's own next hop from
the target. A reflected route to another origin is not sufficient evidence.

For example, after independently verifying Control1 and its route:

    bolt plan run nest::kubernetes::generate_kube_vip_manifest targets=control2 vip=172.21.255.255 survivor=control1

To withdraw an advertiser intentionally:

    bolt plan run nest::kubernetes::generate_kube_vip_manifest targets=control3 vip=172.21.255.255 advertise=false survivor=control2

After each change, wait for actual static-Pod turnover if content changed,
BGP session convergence and the client's kernel next-hop set. An old mirror Pod
may briefly report Ready while its replacement is not yet available. Verify
strict direct readiness and VIP readiness, then inspect fresh logs. Do not infer
service continuity merely from a successful manifest write.

Never remove or maintain the sole surviving advertiser. Before host reset,
reboot or heavy maintenance, prove another healthy advertising path, withdraw
the target and verify client routing no longer selects it. Keep restoration
artifacts outside the watched manifest directory. Do not restore an unhealthy
member just to increase the advertiser count.

## Bounded etcd progress check

`nest::kubernetes::check_etcd` exposes the existing maintenance gate without
running reconciliation. It uses ordinary inventory-backed Bolt escalation on
one explicitly selected voting member. For example:

```sh
bolt plan run nest::kubernetes::check_etcd target=control1 'etcd_servers=["https://172.22.4.8:2379","https://172.22.4.9:2379"]'
```

`etcd_member_names` defaults to the three existing controllers; a different
complete unique odd voting topology of three through seven members must be
explicit. The observer must be in that set. `etcd_servers` is a nonempty unique
TLS seed list, not a membership waiver: native `--cluster` discovery and the
validator must still cover every expected voter exactly once. The supported
endpoint port is 2379. No credential bytes appear in parameters or output.

The guard performs two native endpoint health, status and membership acquisitions,
with `sample_seconds` from one through five (default two) between them. Each
kubectl request has a ten-second request timeout; etcdctl uses a three-second
dial and five-second command timeout. An outer fifteen-second deadline, with
a two-second termination grace, also bounds each command's streaming transport.
No retry, synthetic application write,
snapshot, checksum scan, compaction, defrag or service operation is generated.
Temporary mode-private sample files are removed on normal success/failure.
Transport loss or process termination can leave private scratch, not a receipt
or permission to repeat a disruptive operation.

Both samples require exact unique positive member IDs, one cluster and leader,
consistent raft term, no reported errors, valid committed/applied indexes and
bounded applied-index lag (`max_lag`, zero through 1000, default 1000).
Every member's applied index must advance while member/name/endpoint bindings,
cluster ID, leader and term remain unchanged. Reordered rows are harmless.
A quiet cluster with no observed advancement, a leader turnover or a transient
disagreement refuses conservatively; it is not proof of data loss or permission
to repair/restart etcd. Diagnose only the failed boundary rather than repeating
the fleet update. The old positional validator interface remains a single
snapshot check and never claims advancement.

The returned `nest_etcd_check` contains the sanitized quorum result with decimal
string cluster/member/leader IDs and per-member progress, but always an empty
`reboot_eligible` and `acceptance_recorded=false`. Validator bytes come from the
selected Bolt module, not an assumed installed helper revision. Existing API-only
reconciliation invokes this same gate before mutation and after readiness;
it does not broaden its certificate/etcd mutation authority.

This is only the quorum portion of maintenance admission. It does not verify
the kube-apiserver's actual configured client endpoint list, survivor VIP kernel
route, USB/power coupling, relevant Ceph/storage health, recovery route, prepared
transaction or release/disruption authorization. Those gates remain required
before a real host outage; successful quorum sampling alone cannot enable host
reboot. No fault injection or new cluster operation is authorized by this example.

### Bind quorum sampling to an observed API client's configuration

`nest::kubernetes::check_apiserver_etcd` composes the same progress guard with
read-only discovery on one explicitly selected API/voting member:

```sh
bolt plan run nest::kubernetes::check_apiserver_etcd target=control1
```

It reads the selected module's endpoint projector, the member's static API
manifest and the native `kube-system/kube-apiserver-MEMBER` mirror Pod. Both
must contain the same unique explicit TLS `--etcd-servers` list. The mirror
must belong to the selected node and have one ready, running API container
with a native runtime identity. Unsupported argument forms, unavailable API
reads, malformed inputs, missing status and configuration disagreements refuse;
none are treated as zero failures. The observed list, not a guessed seed list,
is passed to `check_etcd`. Optional `expected_servers` requires an exact set
match with an independently reviewed endpoint policy before quorum acquisition.
Reordered lists do not change identity. The separate `check_etcd` interface
retains explicit seed-list semantics for existing reconciliation callers.

The API observation is repeated after quorum sampling and must retain identical
endpoint, mirror, Pod and container identities. Each native API read has the
same request and outer streaming deadlines as the quorum acquisition. Private
temporary Pod data is removed on ordinary success/failure; only sanitized
endpoint/runtime identities are returned. Parser errors never echo source YAML,
Pod contents or unrelated arguments. No certificate material is returned.

This observes kubelet's reported runtime and current selected manifest, not
an independent process-memory attestation. It is bounded point-in-time evidence
for that member only, not all API clients or ongoing availability. Neither
plan changes endpoints, runs reconciliation, restarts a component, repairs
etcd, records update acceptance or makes a host reboot eligible. Survivor TLS,
actual client kernel route, storage and physical coupling, transaction/release
binding and separately authorized maintenance remain required.

## Heavy control-plane work

No raw snapshot replication or capacity rehearsal may run unbounded on a live
control-plane member. Low-priority `nice`/`ionice` alone does not constrain ZFS
kernel memory or I/O pressure. The interrupted Control3 seed is not authorized
for automatic replay or resume by this routing repair.

Before any future capacity experiment, require an explicit bounded transfer
rate, bounded CPU/userspace memory, elapsed-time limit, exact operation receipts,
and concurrent independent API/etcd/route observations with stop criteria. Verify
those controls on the actual host; do not claim a cgroup memory cap also bounds
ZFS kernel allocation. Preserve resumable targets and snapshots after an
interruption. This document does not supply or certify a replacement transfer
implementation: that pressure-safety gate remains separate from VIP repair.

## Acceptance

Etcd client routing canaries use `nest::kubernetes::reconcile_control_plane`, one
member at a time. That plan renders only the API static manifest through
`kubeadm init phase control-plane apiserver`, using the same config and patches
for dry-run and publication. Do not substitute `kubeadm upgrade node phase
control-plane`: that broader phase can restart etcd and renew Kubernetes
certificates even when only API read endpoints were intended to change.

The installed kubeadm tool must also support the running cluster version. A
Stage 3 root can contain a newer kubeadm than its still-running static Pods;
API-only reconciliation must not turn that mismatch into an implicit cluster
upgrade. The optional `kubeadm_version` argument selects an exact Gentoo binary
package only after checking that it matches the live kubeadm ConfigMap's
`kubernetesVersion`. The previous executable and version are preserved outside
the watched directory. Tool selection is refused with `upgrade_components=true`.
An unavailable binary package fails closed rather than starting a source build.
Omitting the argument leaves the installed tool unchanged.

For a live v1.34.2 cluster with an incompatible newer host tool, for example:

    bolt plan run nest::kubernetes::reconcile_control_plane targets=control2 'etcd_servers=["https://172.22.4.9:2379","https://172.22.4.8:2379"]' kubeadm_version=1.34.2

Afterward, independently verify the installed tool version, actual API
container turnover when required, unchanged etcd containers and public
certificates, direct readiness, quorum and the preserved rollback executable.

The optional host-level `nest::service::kubernetes::apiserver_go_memory_limit`
manages a kubeadm patch setting the API process's `GOMEMLIMIT`. It accepts
positive integer MiB or GiB values; the default is absent. Control2 retains its
qualified `1GiB` budget; Control3 selects `1GiB` for its own guarded canary.
Puppet manages the input file without notifying kubelet or regenerating
static manifests. Use `kubernetes_api_memory` for a narrowly tagged catalog
application, then separately reconcile the API only if its desired input changed.

The Control2 decision retains a stable canary, not a fleet-wide causal claim:
the mature thirty-minute natural-workload window had no sampled strict or
authenticated API failures, unchanged containers, six subsecond etcd compactions
and API RSS between 837705728 and 981229568 bytes. The Go heap cycled through
multiple collections instead of simply remaining small immediately after startup.
Restart effects and workload differences still confound comparison with other
members. `GOMEMLIMIT` is a soft Go-runtime budget, not a hard RSS cap or proof
that ZFS copy/reset pressure is safe. Do not apply this setting to the other
controllers without their own evidence. If the budget harms latency or CPU,
remove the host selection and the exact patch, then restore the preserved API
manifest through a guarded single-member rollback; restoring the manifest alone
would let the next kubeadm reconciliation reintroduce the budget.

Control3's separate canary addresses measured post-defrag pressure, not an
assumed fleet-wide benefit. Its database shrank from about 200 MB to 65 MB, but
a later natural-workload interval still recorded an etcd major-fault step of
5592 and a 3.8-second compaction. Its API RSS was about 1.2 GB while available
host memory fell below 750 MB. This supports testing a bounded Go heap, not a
claim that memory pressure is the sole cause. Control2 serves a different
request mix, so its lower RSS is not a matched causal comparison. Require
Control3's actual heap/GC, CPU, fault, API error-counter, object-read and
compaction evidence before accepting the canary or attempting payload work.
Keep the API-only rollback manifest and remove the host input too if rejected.

Require a sustained log-correlated interval with intended advertisers healthy,
correct external next hops, successful strict API and etcd proposal checks,
advancing synchronized members, no unplanned leader changes or proposal failures,
controllers retaining leases, and healthy critical workloads. Report residual
slow-apply warnings separately from API failures. Any fresh API timeout, missing
route or readiness failure must be diagnosed before control/storage rollout
continues. A canary proves only its exercised behavior, not the full fleet's
Stage 3 acceptance.
