# Read-only survivor readiness from an explicit external client's kernel path.
# This observes a possible survivor; it never withdraws a VIP or admits an outage.
plan nest::kubernetes::check_api_survivor (
  TargetSpec                            $target,
  TargetSpec                            $survivor,
  TargetSpec                            $client,
  Hash[String, Stdlib::IP::Address::V4] $advertisers,
  Stdlib::IP::Address::V4               $vip              = '172.21.255.255',
  String                                $server_name      = 'control-plane.eyrie',
  Optional[Array[String]]               $expected_servers = undef,
  Integer[1, 5]                         $sample_seconds   = 2,
  Integer[0, 1000]                      $max_lag          = 1000,
) {
  $targets = get_targets($target)
  $survivors = get_targets($survivor)
  $clients = get_targets($client)
  $members = ['control1', 'control2', 'control3']
  if $targets.length != 1 or $survivors.length != 1 or $clients.length != 1 {
    fail_plan('Require one maintenance target, survivor and external client', 'nest/api-survivor-inputs')
  }
  $member = $targets[0]
  $spare = $survivors[0]
  $observer = $clients[0]
  if !($member.name in $members) or !($spare.name in $members) or
    $member.name == $spare.name or $observer.name in $members or
    $observer.name !~ Pattern[/\A[a-z0-9][a-z0-9.-]{0,127}\z/] or
    $advertisers.empty or $advertisers.length > 3 or !$advertisers.keys.all |$name| { $name in $members } or
    !($spare.name in $advertisers) or $advertisers.values.unique.length != $advertisers.length or
    $server_name !~ Pattern[/\A[a-z0-9][a-z0-9.-]{0,252}\z/] {
    fail_plan('Require a different declared survivor, unique advertiser addresses and external client', 'nest/api-survivor-inputs')
  }
  if $expected_servers != undef and ($expected_servers.empty or $expected_servers.length > 7 or
    $expected_servers.unique != $expected_servers or
    !$expected_servers.all |$endpoint| { $endpoint =~ Pattern[/\Ahttps:\/\/(?:[a-z0-9][a-z0-9.-]*|\[[0-9a-f:]+\]):2379\z/] }) {
    fail_plan('Invalid expected API TLS endpoint identities', 'nest/api-survivor-inputs')
  }
  $source = file('nest/kubernetes/api-survivor-observation.rb')
  $survivor_ip = $advertisers[$spare.name]
  $vip_args = ['vip', $spare.name, $vip, $survivor_ip, '/etc/kubernetes/manifests/kube-vip.yaml'].shellquote
  $pod_command = [
    'timeout', '--signal=TERM', '--kill-after=2s', '15s',
    'kubectl', '--request-timeout=10s', '--kubeconfig=/etc/kubernetes/admin.conf',
    '-n', 'kube-system', 'get', 'pod', "kube-vip-${spare.name}", '-o', 'json',
  ].shellquote
  $vip_template = @(COMMAND/L)
    set -eu
    umask 077
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/nest-api-survivor.XXXXXX")"
    trap 'rm -rf "$tmpdir"' EXIT
    cat > "$tmpdir/project.rb" <<'NEST_API_SURVIVOR_RUBY'
    __SOURCE__
    NEST_API_SURVIVOR_RUBY
    __POD__ > "$tmpdir/pod.json"
    ruby "$tmpdir/project.rb" __ARGS__ < "$tmpdir/pod.json"
    | COMMAND
  $vip_command = $vip_template.regsubst('__SOURCE__', $source, 'G').regsubst('__POD__', $pod_command, 'G').regsubst('__ARGS__', $vip_args, 'G')
  $route_args = ['route', $vip, $survivor_ip, $advertisers.values.sort.join(',')].shellquote
  $routes = ['timeout', '5s', 'ip', '-j', '-4', 'route', 'show', 'table', '100', 'exact', "${vip}/32"].shellquote
  $lookup = ['timeout', '5s', 'ip', '-j', '-4', 'route', 'get', $vip].shellquote
  $route_template = @(COMMAND/L)
    set -eu
    umask 077
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/nest-api-survivor.XXXXXX")"
    trap 'rm -rf "$tmpdir"' EXIT
    cat > "$tmpdir/project.rb" <<'NEST_API_SURVIVOR_RUBY'
    __SOURCE__
    NEST_API_SURVIVOR_RUBY
    __ROUTES__ > "$tmpdir/routes.json"
    __LOOKUP__ > "$tmpdir/lookup.json"
    ruby -rjson -e 'puts JSON.generate("routes" => JSON.parse(File.read(ARGV[0])), "lookup" => JSON.parse(File.read(ARGV[1])))' "$tmpdir/routes.json" "$tmpdir/lookup.json" > "$tmpdir/input.json"
    ruby "$tmpdir/project.rb" __ARGS__ < "$tmpdir/input.json"
    | COMMAND
  $route_command = $route_template.regsubst('__SOURCE__', $source, 'G').regsubst('__ROUTES__', $routes, 'G')
    .regsubst('__LOOKUP__', $lookup, 'G').regsubst('__ARGS__', $route_args, 'G')
  $before_vip = parsejson(run_command($vip_command, $spare, 'Observe surviving VIP policy and ready mirror runtime', '_run_as' => 'root').results[0].value['stdout'])
  $before_route = parsejson(run_command($route_command, $observer, 'Require actual client kernel path through declared survivor', '_run_as' => 'root').results[0].value['stdout'])
  # Disable curlrc/proxies/redirects and resolve the same TLS name separately to
  # the direct survivor and VIP. No insecure bypass, credential or retry.
  $probe_commands = [$survivor_ip, $vip].map |$address| {
    [
      'curl', '-q', '--fail', '--silent', '--show-error', '--noproxy', '*',
      '--connect-timeout', '3', '--max-time', '5', '--proto', '=https',
      '--cacert', '/etc/kubernetes/pki/ca.crt', '--output', '/dev/null',
      '--resolve', "${server_name}:6443:${address}", "https://${server_name}:6443/readyz",
    ].shellquote
  }
  run_command($probe_commands.join(' && '), $observer, 'Require CA-verified direct survivor and VIP readiness from client', '_run_as' => 'root')
  $backend = run_plan('nest::kubernetes::check_apiserver_etcd', {
    'target'           => $spare.name,
    'expected_servers' => $expected_servers,
    'sample_seconds'   => $sample_seconds,
    'max_lag'          => $max_lag,
  })
  run_command($probe_commands.join(' && '), $observer, 'Recheck client TLS readiness after bounded quorum observation', '_run_as' => 'root')
  $after_route = parsejson(run_command($route_command, $observer, 'Require stable client kernel next-hop set', '_run_as' => 'root').results[0].value['stdout'])
  $after_vip = parsejson(run_command($vip_command, $spare, 'Require unchanged surviving VIP runtime and policy', '_run_as' => 'root').results[0].value['stdout'])
  if !($before_route =~ Hash) or $before_route['kind'] != 'nest_api_survivor_route' or
    !($before_vip =~ Hash) or $before_vip['kind'] != 'nest_api_survivor_vip' or
    $before_route != $after_route or $before_vip != $after_vip {
    fail_plan('Survivor runtime or client kernel route changed during observation', 'nest/api-survivor-continuity')
  }
  return({
    'schema'              => 1,
    'kind'                => 'nest_api_survivor_check',
    'target'              => $member.name,
    'client'              => $observer.name,
    'server_name'         => $server_name,
    'vip'                 => $before_vip,
    'route'               => $before_route,
    'backend'             => $backend,
    'reboot_eligible'     => [],
    'acceptance_recorded' => false,
  })
}
