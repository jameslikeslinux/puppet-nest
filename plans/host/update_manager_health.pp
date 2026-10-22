# Observe one host's actual manager inventory; this does not accept a transaction.
plan nest::host::update_manager_health (
  TargetSpec $target,
) {
  $nodes = get_targets($target)
  if $nodes.length != 1 {
    fail_plan('Manager observation requires exactly one host', 'nest/update-manager-health-target')
  }
  $result = run_task('nest::update_manager_health', $nodes[0], {
    '_run_as' => 'root',
  })
  return $result.first.value
}
