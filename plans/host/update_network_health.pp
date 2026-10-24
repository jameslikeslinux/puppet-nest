# Observe one host's client paths; this does not accept a transaction.
plan nest::host::update_network_health (
  TargetSpec   $target,
  Array[Hash]  $endpoints,
) {
  $nodes = get_targets($target)
  if $nodes.length != 1 {
    fail_plan('Network observation requires exactly one host', 'nest/update-network-health-target')
  }
  $result = run_task('nest::update_network_health', $nodes[0], {
    'endpoints' => $endpoints,
  })
  return $result.first.value
}
