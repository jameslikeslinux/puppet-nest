# Observe exact etcd topology and progress without changing cluster state.
# This is a point-in-time guard, not complete host maintenance authorization.
plan nest::kubernetes::check_etcd (
  TargetSpec       $target,
  Array[String]    $etcd_servers,
  Array[String]    $etcd_member_names = ['control1', 'control2', 'control3'],
  Integer[1, 5]    $sample_seconds    = 2,
  Integer[0, 1000] $max_lag           = 1000,
) {
  $nodes = get_targets($target)
  if $nodes.length != 1 or $etcd_member_names.length < 3 or $etcd_member_names.length > 7 or
    $etcd_member_names.length % 2 != 1 or $etcd_member_names.unique != $etcd_member_names or
    $etcd_servers.empty or $etcd_servers.length > 7 or $etcd_servers.unique != $etcd_servers {
    fail_plan('Require one observer and an exact unique odd voting topology', 'nest/etcd-check-inputs')
  }
  $member = $nodes[0]
  if !($member.name in $etcd_member_names) or
    !$etcd_member_names.all |$name| { $name =~ Pattern[/\A[a-z0-9][a-z0-9.-]{0,127}\z/] } or
    !$etcd_servers.all |$endpoint| { $endpoint =~ Pattern[/\Ahttps:\/\/(?:[a-z0-9][a-z0-9.-]*|\[[0-9a-f:]+\]):2379\z/] } {
    fail_plan('Invalid explicit etcd member or TLS endpoint identity', 'nest/etcd-check-inputs')
  }
  $native = [
    'timeout', '--signal=TERM', '--kill-after=2s', '15s',
    'kubectl', '--request-timeout=10s', '--kubeconfig=/etc/kubernetes/admin.conf',
    '-n', 'kube-system', 'exec', "etcd-${member.name}", '--',
    'etcdctl', '--dial-timeout=3s', '--command-timeout=5s', "--endpoints=${etcd_servers.join(',')}",
    '--cacert=/etc/kubernetes/pki/etcd/ca.crt',
    '--cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt',
    '--key=/etc/kubernetes/pki/etcd/healthcheck-client.key',
  ].shellquote
  # Use the reviewed module bytes, not an unverified older installed helper.
  $validator_source = file('nest/kubernetes/validate-etcd-cluster.rb')
  $command_template = @(COMMAND/L)
    set -eu
    umask 077
    tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/nest-etcd-check.XXXXXX")"
    trap 'rm -rf "$tmpdir"' EXIT
    cat > "$tmpdir/validate.rb" <<'NEST_ETCD_VALIDATOR_RUBY'
    __VALIDATOR_SOURCE__
    NEST_ETCD_VALIDATOR_RUBY
    __NATIVE__ endpoint health --cluster --write-out=json > "$tmpdir/health-before.json"
    __NATIVE__ endpoint status --cluster --write-out=json > "$tmpdir/before.json"
    __NATIVE__ member list --write-out=json > "$tmpdir/members-before.json"
    ruby "$tmpdir/validate.rb" "$tmpdir/before.json" "$tmpdir/members-before.json" __LAG__ __NAMES__ > /dev/null
    sleep __SECONDS__
    __NATIVE__ endpoint health --cluster --write-out=json > "$tmpdir/health-after.json"
    __NATIVE__ endpoint status --cluster --write-out=json > "$tmpdir/after.json"
    __NATIVE__ member list --write-out=json > "$tmpdir/members-after.json"
    ruby "$tmpdir/validate.rb" --json --previous-status "$tmpdir/before.json" --previous-members "$tmpdir/members-before.json" "$tmpdir/after.json" "$tmpdir/members-after.json" __LAG__ __NAMES__
    | COMMAND
  $command = $command_template
    .regsubst('__NATIVE__', $native, 'G')
    .regsubst('__VALIDATOR_SOURCE__', $validator_source, 'G')
    .regsubst('__NAMES__', $etcd_member_names.shellquote, 'G')
    .regsubst('__LAG__', String($max_lag), 'G')
    .regsubst('__SECONDS__', String($sample_seconds), 'G')
  $observed = run_command($command, $member, 'Require exact healthy advancing etcd topology', {
    '_run_as' => 'root',
  })
  $quorum = parsejson($observed.results[0].value['stdout'])
  if !($quorum =~ Hash) or $quorum['schema'] != 1 or $quorum['kind'] != 'nest_etcd_quorum_observation' or
    $quorum['result'] != 'pass' or $quorum['advancing'] != true or $quorum['acceptance_recorded'] != false {
    fail_plan('Etcd validator did not return a bound advancing observation', 'nest/etcd-check-result')
  }
  return({
    'schema'              => 1,
    'kind'                => 'nest_etcd_check',
    'observer'            => $member.name,
    'endpoints'           => $etcd_servers,
    'sample_seconds'      => $sample_seconds,
    'quorum'              => $quorum,
    'reboot_eligible'     => [],
    'acceptance_recorded' => false,
  })
}
