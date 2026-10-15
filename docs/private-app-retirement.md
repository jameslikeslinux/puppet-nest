# Private application retirement and recovery

Scope: Vesture, Portfolio, The Static Void, Implicit Creations, Plug Love,
and the Portfolio/The Static Void test copies. No public archive or replacement
site is provided. Public DNS, domain registrations, email, GitLab, and shared
storage/database infrastructure are not retired by this change.

## Preservation boundary

Private retirement generations live under `/nest/backup/retired-apps/`, outside
rolling service backups such as `/nest/backup/portfolio/`. These are permanent
archives: no time-based expiry or rolling-backup pruning applies. Deletion
requires a separate explicit owner decision. Keep the complete generation,
its SHA256 manifest, restore receipts, original deployment resources, runtime
images, and recovery instructions together. Do not attach the generation or
its raw manifests, databases, exports, configuration, or media to chat or issues.

The task's final safe evidence identifies the completed generation and its
manifest hash. Read its private `RECOVERY.md` locally as an authorized operator.
A successful backup alone is not a retirement gate: final data must actually
restore into an isolated environment before any service uninstall.

Each WordPress copy preserves full SQL and its cold MariaDB datadir, the entire
persisted WordPress volume (including configuration/plugins/themes/uploads),
the exact running core where a pod existed, an OCI runtime archive, rendered
Helm resources and values, file checksums, and a supplemental WXR content export.
Vesture preserves its full persisted volume, SQLite SQL, a tested native backup,
complete source history/revision, OCI runtime, original configuration and resource
metadata. Legacy gateway-local site files and scoped proxy/renewal configuration
are preserved separately in the same generation.

## Restore safely, not automatically

1. Verify the complete generation against its checksum manifest before use.
   Copy it into a private local working directory; never restore in place over
   the retained archive or original PVCs.
2. Load the archived OCI images rather than relying on mutable tags or vendor
   availability. Use the archived deployment metadata to understand mounts,
   database names, table prefixes, versions, and original configuration.
3. Use a network-isolated temporary environment: no public ingress or host
   ports, no outbound network, no mounted host credentials/service account,
   no cron/event scheduler/queue workers, no email, payment, webhook, or other
   integration calls. Network isolation is the hard boundary, not merely
   application flags or a staging URL.
4. For WordPress, initialize a fresh isolated MariaDB and import the per-site
   `application.sql`. The complete `all-databases.sql` and cold datadir retain
   historical system/user state; do not blindly import old system schemas into
   a newer server. The retired databases had legacy `mysql.proc` schema drift;
   application routines were absent. No live schema upgrade was performed.
5. Restore persisted WordPress files plus the archived core/runtime. Generate
   restore-only DB connection settings and local URLs. Disable WP cron, mail,
   external HTTP, background action runners and updates before starting PHP.
   Preserve the original secret-bearing configuration unchanged in the archive.
6. For Vesture, use its archived runtime and native `vesture-final.zip` with
   `python -m vesture.cli restore --input <private-copy>`. Point data/media dirs
   only at the isolated copy. Check SQLite integrity, table counts and all
   recorded media hashes before testing the read-only UI/API.
7. Verify schema/table/row counts, representative content and media bytes, and
   app behavior. Keep restoration private. Reconnecting integrations, renewing
   public TLS, publishing routes or reinstating a service is a new operation,
   not part of archive verification.

Retained original PVCs/PVs are an additional recovery option, not a substitute
for the independently tested archive. Do not delete them, their datasets, or
shared namespaces without separate explicit authorization. Do not revive the
removed deploy/restore timers to recover one archive.

## Public DNS checklist for Joy

Only remove the obsolete website records (A/AAAA/CNAME/website redirects) when
ready. Do not remove whole zones, registrations, MX, mail authentication,
GitLab/registry subdomains, or other service records.

- `joyfullee.me`, `www.joyfullee.me`, `james.tl`, `www.james.tl`
- `thestaticvoid.com`, `www.thestaticvoid.com`
- `thestaticvoid.org`, `www.thestaticvoid.org`
- `tsv.co`, `www.tsv.co`
- `pluglove.net`, `www.pluglove.net`

Gateway website addresses observed before retirement: `45.77.156.204` and
`2001:19f0:1000:e1dc::204`; Plug Love uses `64.176.222.44` and
`2001:19f0:1000:e1dc::44`. Preserve these shared addresses for any other users;
this is a record checklist, not authorization to remove interfaces or routes.
Implicit Creations and Vesture had only internal ingress in the scoped source
and live inventory. Internal retired aliases are removed from managed DNS.

## Gateway and staged-root boundary

Remove only app-owned vhosts/proxies and exclusive renewal references. Keep
shared HTTP/HTTPS firewall access and unrelated vhosts/certificates, especially
GitLab, registry, vault and requests. Removing a default website must not make
another public service a holding page for retired hostnames; verify unknown-host
behavior as well as named-vhost absence. The previously built gateway/router
staged roots must receive the same scoped config retirement before future boot;
no fleet rebuild, reboot or CA cutover is implied.
