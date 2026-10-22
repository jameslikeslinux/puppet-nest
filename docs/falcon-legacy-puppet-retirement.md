# Falcon legacy Puppet retirement

## Management contract

Production agents use `puppet.eyrie`, with short certnames. Bolt inventory uses
`https://puppetdb.eyrie:443`, validated against `files/certs/eyrie.crt` via
`/etc/puppetlabs/bolt/ingress-ca.pem`. The explicit port matters: OpenBolt otherwise
uses port 8081 even for an HTTPS URL without a port. This is the existing internal
read-only PuppetDB ingress, not a new unauthenticated endpoint or TLS bypass.
Legacy Bolt client certificates and keys are no longer selected by managed config;
existing files remain untouched for rollback. Do not print their contents.

`bolt plan run nest::puppet::deploy` deploys test and production OpenVox and expires
both compiler environment caches. `backend=test` and `backend=prod` select one.
`kubernetes`, `both`, and `all` mean test plus production. `legacy` is rejected.
Node deletion explicitly selects the production or test OpenVox namespace; it is
not part of retirement and must not be run as a verification probe.

The existing Falcon `r10k` runner identity/tag is retained for compatibility, but
its job uses the ordinary Bolt deployment plan. Its managed image, trust mounts,
Forge environment and existing Eyrie kubeconfig mount replace the legacy
`/srv/puppet` mounts. `nest::tool::bolt::deploy` installs the same encrypted code
deployment key used by the OpenVox sidecars at a separate root-only client path;
it does not reuse the host's Eyrie transport key. This is a trusted administrative
deployment runner, not an untrusted-code sandbox. Drain the shared runner manager before reconciling its
registration, preserving prior admission states; never interrupt ongoing builds.

`nest::service::puppet` remains the shared OpenVox credential/marker class used by
KubeCM. Its Podman branch is removed and fails closed if accidentally selected on
a host. Do not delete its encrypted Hiera credentials or Kubernetes resources.

## Offline rollback material

Retain the complete Falcon datasets, mounted at `/srv/puppet`:

- `data/crypt/srv/puppet` and its `code`, `postgres`, `puppetdb`, `puppetserver`, and
  `r10k` children, including the old server SSL directory, CA and deployment key.
- Root-only copies of the old systemd units and configuration under
  `/srv/puppet/retirement`, archived before disabling them. Existing stopped
  containers/images may be retained, but they are not the only rollback copy:
  the ordinary Podman prune timer can remove old stopped containers.
- Existing secure production backups at `/nest/backup/puppet/puppet-ssl.tar.zst`,
  `puppetdb.dump`, and `metadata.json`; production backups are distinct from the
  legacy datasets and must continue normally.
- Git history before this retirement preserves the old class, runner volumes,
  DNS/proxy entries, and `/srv/puppet/bin/r10k` configuration.

The retired units are `container-puppetserver.service`,
`container-puppetdb.service`, `container-puppet-postgres.service`,
`container-puppetboard.service`, and `pod-puppet.service`. Disable and stop only
these names after management clients and code deployment pass their checks.
Do not delete persistent data, revoke CA identities, reboot Falcon, or operate on
Kubernetes OpenVox pods/PVCs as part of the shutdown.

Rollback is an explicit supervised operation, not an automatic fallback. Before
starting the old stack, check for listener conflicts and current management
routing. Restore only the retained legacy units/configuration, reload systemd,
and enable/start the pod and its containers using inventory-backed Bolt. Never
replace the production CA, database or migrated agent identities with the old
ones. If retired source is needed, inspect the pre-retirement revision in an
isolated worktree rather than resetting the active repository or managed hosts.

## Pre-retirement evidence

The initial fresh-worktree Bolt preflight failed before transport because
`ruby_task_helper` was not installed. `bolt module install` fixed that dependency;
the inventory-backed Owl transport then returned user `joy`, hostname `owl`.
The new endpoint returned Owl, Falcon and both console identities, and real Bolt
transport succeeded on Owl, Falcon-console and Kestrel-console. No console
catalogs were run during that transport check. Retired Eagle variants and
`owl.nest` were not revived.

A fresh Falcon Podman measurement before mutation reported:

| Container | Attributed memory |
| --- | ---: |
| puppetserver | 1.149 GB |
| puppetdb | 654.4 MB |
| puppet-postgres | 153.3 MB |
| puppetboard | 50.48 MB |

Whole-host available memory was 20,857,868,288 bytes. This is a separate,
workload-dependent measure, not a promise of equal before/after free-memory gain.
All five legacy units were active and enabled. The correct legacy dataset prefix
is `data/crypt/srv/puppet`; a probe of `data/crypt/puppet` failed without mutation.

Production OpenVox server identity was `puppet.eyrie`; CA SHA256 fingerprint:
`2F:38:AB:32:14:98:AB:20:9E:3C:80:54:E3:69:AB:48:DB:D5:E5:E3:0E:9C:6F:1E:4D:04:B5:5A:EF:C0:3E:6E`.
The production backup job completed at `2026-10-22T13:50:34Z`; SSL archive,
PuppetDB dump and metadata were present. Representative successful production
reports included Owl unchanged at `2026-10-22T14:05:03.730Z`, Falcon-console
unchanged at `2026-10-22T04:01:30.645Z`, and Kestrel-console changed at
`2026-10-22T04:20:20.990Z`. Several unrelated full-host reports were already failed;
retirement does not imply those failures have been fixed.

The OpenVox-only code deployment plan ran successfully against both namespaces,
including r10k and environment-cache expiry, before shutdown. Final merged
revision, installed-client checks, shutdown and post-retirement evidence must be
recorded in the task handoff before this retirement can be called complete.

## Verification status

Local `pdk validate` passed before the focused management regression was added.
The public Nest class suite passed with 1129 examples and no failures.
The broader focused run exposed two existing failures in
`spec/data/kubernetes_config_image_spec.rb`: it expects Hermes backup
`imagePullPolicy: IfNotPresent`, while the unchanged baseline source already uses
`Always`. Both the spec and Hermes dashboard data are unchanged by this retirement.
These local failures must not be hidden. The independently verified GitLab
pipeline for initial revision `aef7e550b8b09dd0fea14d9258b636d330241d74` did pass all
jobs, including 1338 unit examples with no failures. Treat the local discrepancy
separately from CI; every subsequent revision still needs its own exact-head gate.

An ephemeral deployment-image check on Falcon verified Kubernetes access and
successful private module installation using the existing shared code-deploy
key. The host Eyrie transport key did not authenticate to GitLab; it was not
adopted for CI. The root-only pre-retirement archive was created and listed at
`/srv/puppet/retirement/systemd-and-bolt-before-retirement.tar.gz` (mode 0600),
containing all five units and the existing Bolt configuration. No private bytes
were printed.
