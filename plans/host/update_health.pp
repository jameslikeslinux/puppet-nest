# Collect existing boot and manager observations without accepting a transaction.
plan nest::host::update_health (
  TargetSpec            $target,
  Hash[String, String]  $expectations,
) {
  $nodes = get_targets($target)
  if $nodes.length != 1 {
    fail_plan('Health observation requires exactly one host', 'nest/update-health-target')
  }
  $boot_before = run_plan('nest::host::update_boot_health',
    target       => $nodes[0],
    expectations => $expectations,
  )
  $managers = run_plan('nest::host::update_manager_health', target => $nodes[0])
  $boot_after = run_plan('nest::host::update_boot_health',
    target       => $nodes[0],
    expectations => $expectations,
  )

  # Bracket manager acquisition. Transport success and independent green samples
  # are insufficient when they belong to different boots or storage identities.
  $boot_identity = $boot_before['schema'] == 1 and $boot_before['kind'] == 'nest_update_boot_health' and
    $boot_before['acceptance_recorded'] == false and $boot_before['hostname'] == $expectations['hostname'] and
    $boot_before['boot_id'] =~ Pattern[/\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/] and
    $boot_before == $boot_after
  $manager_identity = $managers['schema'] == 1 and $managers['kind'] == 'nest_update_manager_health' and
    $managers['acceptance_recorded'] == false and $managers['hostname'] == $boot_before['hostname'] and
    $managers['boot_id'] == $boot_before['boot_id']
  $bound = $boot_identity and $manager_identity
  $healthy = $bound and $boot_before['result'] == 'pass' and $managers['result'] == 'pass'
  $outcome = $healthy ? {
    true    => 'pass',
    default => 'fail',
  }
  return({
    'schema'               => 1,
    'kind'                 => 'nest_update_health',
    'result'               => $outcome,
    'observations_bound'   => $bound,
    'boot_before'          => $boot_before,
    'managers'             => $managers,
    'boot_after'           => $boot_after,
    'acceptance_recorded'  => false,
  })
}
