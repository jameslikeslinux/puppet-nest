# Read-only composition consumed immediately by maintenance and preparation.
# Declared physical independence is not hardware discovery or outage authority.
plan nest::kubernetes::check_control_plane_maintenance (
  TargetSpec                            $target,
  TargetSpec                            $survivor,
  TargetSpec                            $client,
  Hash[String, Stdlib::IP::Address::V4] $advertisers,
  Hash[String, Array[String, 1, 32]]     $physical_domains,
  Optional[String]                      $ceph_fsid,
  Stdlib::IP::Address::V4               $vip              = '172.21.255.255',
  Optional[Array[String]]               $expected_servers = undef,
) {
  $nodes = get_targets($target)
  $spares = get_targets($survivor)
  $clients = get_targets($client)
  $voters = ['control1', 'control2', 'control3']
  $storage_nodes = get_targets('eyrie-storage').map |$node| { $node.name }
  if $nodes.length != 1 or $spares.length != 1 or $clients.length != 1 or $storage_nodes.empty {
    fail_plan('Maintenance requires one exact target, survivor, external client and known inventory storage members', 'nest/maintenance-scope')
  }
  $member = $nodes[0].name
  $spare = $spares[0].name
  $observer = $clients[0].name
  $protected = ($voters + $storage_nodes + [$observer]).unique - [$member]
  $required = ($protected + [$member]).unique
  if !($member in $voters) or !($spare in $voters) or $member == $spare or $observer in $voters or
    !($spare in $advertisers) or ($ceph_fsid != undef and $ceph_fsid !~ Pattern[/\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/]) or
    !$required.all |$name| { $name in $physical_domains } or
    !$physical_domains.values.all |$domains| {
      $domains.unique == $domains and $domains.all |$domain| { $domain =~ Pattern[/\A[a-z0-9][a-z0-9_.-]{0,127}\z/] }
    } {
    fail_plan('Require complete reviewed physical/USB/power memberships, exact cluster identity and a different serving survivor', 'nest/maintenance-scope')
  }
  if $protected.any |$name| { !$physical_domains[$member].filter |$domain| { $domain in $physical_domains[$name] }.empty } {
    fail_plan('Maintenance target overlaps a protected voter, storage member or client physical/USB/power domain', 'nest/maintenance-physical-domain')
  }

  $source = file('nest/kubernetes/maintenance-storage.rb')
  $ceph_native = [
    'timeout', '--signal=TERM', '--kill-after=2s', '20s',
    'kubectl', '--request-timeout=10s', '-n', 'rook-ceph', 'exec',
    'deployment/rook-ceph-tools', '--', 'ceph', 'status', '--format', 'json',
  ].shellquote
  $ceph_identity = $ceph_fsid ? {
    undef   => '',
    default => $ceph_fsid,
  }
  $ceph_args = ['ceph', $ceph_identity].shellquote
  $ceph_template = @(COMMAND/L)
    set -eu
    export LC_ALL=C
    umask 077
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/nest-maintenance.XXXXXX")"
    trap 'rm -rf "$tmpdir"' EXIT
    cat > "$tmpdir/project.rb" <<'NEST_MAINTENANCE_RUBY'
    __SOURCE__
    NEST_MAINTENANCE_RUBY
    __NATIVE__ > "$tmpdir/ceph.json"
    ruby "$tmpdir/project.rb" __ARGS__ < "$tmpdir/ceph.json"
    | COMMAND
  $ceph_command = $ceph_template.regsubst('__SOURCE__', $source, 'G').regsubst('__NATIVE__', $ceph_native, 'G').regsubst('__ARGS__', $ceph_args, 'G')
  $etcd_template = @(COMMAND/L)
    set -eu
    export LC_ALL=C
    umask 077
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/nest-maintenance.XXXXXX")"
    trap 'rm -rf "$tmpdir"' EXIT
    cat > "$tmpdir/project.rb" <<'NEST_MAINTENANCE_RUBY'
    __SOURCE__
    NEST_MAINTENANCE_RUBY
    timeout 5s findmnt --json -T /var/lib/etcd -o SOURCE,FSTYPE > "$tmpdir/mounts.json"
    pool="$(ruby -rjson -e 'm = JSON.parse(File.read(ARGV[0])).fetch("filesystems"); abort unless m.length == 1 && m[0]["fstype"] == "zfs"; p = m[0].fetch("source").split("/")[0]; abort unless p.match?(/\A[A-Za-z][A-Za-z0-9_.-]*\z/); puts p' "$tmpdir/mounts.json")"
    timeout 5s zpool list -Hp -o name,guid,health > "$tmpdir/pools.txt"
    timeout 5s zpool status -x "$pool" > "$tmpdir/status.txt"
    ruby -rjson -e 'puts JSON.generate("mounts" => JSON.parse(File.read(ARGV[0])), "pools" => File.read(ARGV[1]), "status" => File.read(ARGV[2]))' "$tmpdir/mounts.json" "$tmpdir/pools.txt" "$tmpdir/status.txt" > "$tmpdir/input.json"
    ruby "$tmpdir/project.rb" etcd < "$tmpdir/input.json"
    | COMMAND
  $etcd_command = $etcd_template.regsubst('__SOURCE__', $source, 'G')
  $before_storage = $voters.map |$voter| {
    parsejson(run_command($etcd_command, $voter, 'Require actual etcd backing pool availability', '_run_as' => 'root').results[0].value['stdout'])
  }
  if $ceph_fsid != undef {
    $before_ceph = parsejson(run_command($ceph_command, $observer, 'Require Ceph availability without clearing retained warnings', '_run_as' => 'root').results[0].value['stdout'])
  } else {
    $before_ceph = { 'result' => 'not_requested_api_only' }
  }
  $api = run_plan('nest::kubernetes::check_api_survivor', {
    'target'           => $member,
    'survivor'         => $spare,
    'client'           => $observer,
    'advertisers'      => $advertisers,
    'vip'              => $vip,
    'expected_servers' => $expected_servers,
  })
  if $ceph_fsid != undef {
    $after_ceph = parsejson(run_command($ceph_command, $observer, 'Recheck Ceph availability after survivor observation', '_run_as' => 'root').results[0].value['stdout'])
  } else {
    $after_ceph = { 'result' => 'not_requested_api_only' }
  }
  $after_storage = $voters.map |$voter| {
    parsejson(run_command($etcd_command, $voter, 'Require unchanged etcd storage identity and health', '_run_as' => 'root').results[0].value['stdout'])
  }
  if $before_storage != $after_storage or $before_ceph != $after_ceph {
    fail_plan('Storage availability identities changed during maintenance preflight', 'nest/maintenance-storage-continuity')
  }
  return({
    'schema'                      => 1,
    'kind'                        => 'nest_control_plane_maintenance_check',
    'target'                      => $member,
    'api'                         => $api,
    'etcd_storage'                => $before_storage,
    'ceph'                        => $before_ceph,
    'physical_independence'       => 'declared_policy_only',
    'reboot_eligible'             => [],
    'acceptance_recorded'         => false,
  })
}
