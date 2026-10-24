# Bind the bounded quorum guard to one API server's observed client endpoints.
# No reconciliation, endpoint changes, maintenance or reboot authorization.
plan nest::kubernetes::check_apiserver_etcd (
  TargetSpec               $target,
  Optional[Array[String]]  $expected_servers  = undef,
  Array[String]            $etcd_member_names = ['control1', 'control2', 'control3'],
  Integer[1, 5]            $sample_seconds    = 2,
  Integer[0, 1000]         $max_lag           = 1000,
) {
  $nodes = get_targets($target)
  if $nodes.length != 1 or !($nodes[0].name in $etcd_member_names) or
    $etcd_member_names.length < 3 or $etcd_member_names.length > 7 or $etcd_member_names.length % 2 != 1 or
    $etcd_member_names.unique != $etcd_member_names or
    !$etcd_member_names.all |$name| { $name =~ Pattern[/\A[a-z0-9][a-z0-9.-]{0,127}\z/] } {
    fail_plan('Require one API observer in an exact unique odd voting topology', 'nest/apiserver-etcd-inputs')
  }
  if $expected_servers != undef and ($expected_servers.empty or $expected_servers.length > 7 or
    $expected_servers.unique != $expected_servers or
    !$expected_servers.all |$endpoint| { $endpoint =~ Pattern[/\Ahttps:\/\/(?:[a-z0-9][a-z0-9.-]*|\[[0-9a-f:]+\]):2379\z/] }) {
    fail_plan('Invalid expected API TLS endpoint identities', 'nest/apiserver-etcd-inputs')
  }
  $member = $nodes[0]
  $read_pod = [
    'timeout', '--signal=TERM', '--kill-after=2s', '15s',
    'kubectl', '--request-timeout=10s', '--kubeconfig=/etc/kubernetes/admin.conf',
    '-n', 'kube-system', 'get', 'pod', "kube-apiserver-${member.name}", '-o', 'json',
  ].shellquote
  $projector_source = file('nest/kubernetes/apiserver-etcd-endpoints.rb')

  $project_args = [$member.name, '/etc/kubernetes/manifests/kube-apiserver.yaml'].shellquote
  $template = @(COMMAND/L)
    set -eu
    umask 077
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/nest-api-etcd-check.XXXXXX")"
    trap 'rm -rf "$tmpdir"' EXIT
    cat > "$tmpdir/project.rb" <<'NEST_API_ETCD_PROJECTOR_RUBY'
    __PROJECTOR_SOURCE__
    NEST_API_ETCD_PROJECTOR_RUBY
    __READ_POD__ > "$tmpdir/pod.json"
    ruby "$tmpdir/project.rb" __PROJECT_ARGS__ < "$tmpdir/pod.json"
    | COMMAND
  $command = $template.regsubst('__READ_POD__', $read_pod, 'G')
    .regsubst('__PROJECTOR_SOURCE__', $projector_source, 'G').regsubst('__PROJECT_ARGS__', $project_args, 'G')
  $before_result = run_command($command, $member, 'Observe configured and ready API client endpoints', '_run_as' => 'root')
  $before = parsejson($before_result.results[0].value['stdout'])
  if !($before =~ Hash) or $before['schema'] != 1 or $before['kind'] != 'nest_apiserver_etcd_endpoints' or
    $before['observer'] != $member.name or $before['acceptance_recorded'] != false or
    !($before['endpoints'] =~ Array[String]) or $before['endpoints'].empty {
    fail_plan('Missing bound API client endpoint observation', 'nest/apiserver-etcd-result')
  }
  if $expected_servers != undef and $before['endpoints'].sort != $expected_servers.sort {
    fail_plan('Observed API endpoints differ from explicit policy', 'nest/apiserver-etcd-policy')
  }
  $quorum = run_plan('nest::kubernetes::check_etcd', {
    'target'            => $member.name,
    'etcd_servers'      => $before['endpoints'],
    'etcd_member_names' => $etcd_member_names,
    'sample_seconds'    => $sample_seconds,
    'max_lag'           => $max_lag,
  })
  $after_result = run_command($command, $member, 'Require unchanged API client and runtime identity after quorum sampling', '_run_as' => 'root')
  $after = parsejson($after_result.results[0].value['stdout'])
  if $before != $after {
    fail_plan('API client configuration or runtime changed during quorum observation', 'nest/apiserver-etcd-continuity')
  }
  return({
    'schema'              => 1,
    'kind'                => 'nest_apiserver_etcd_check',
    'api'                 => $before,
    'etcd'                => $quorum,
    'reboot_eligible'     => [],
    'acceptance_recorded' => false,
  })
}
