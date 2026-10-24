# Collect existing boot and manager observations without accepting a transaction.
plan nest::host::update_health (
  TargetSpec            $target,
  Hash[String, String]  $expectations,
  Array[Hash]           $endpoints = [],
  Optional[Hash]        $retention = undef,
) {
  $nodes = get_targets($target)
  if $nodes.length != 1 {
    fail_plan('Health observation requires exactly one host', 'nest/update-health-target')
  }
  if $retention != undef {
    if $retention.keys.sort != ['output_dir', 'release', 'transaction'] {
      fail_plan('Health retention requires exact transaction, release and output_dir fields', 'nest/update-health-retention')
    }
    $retain_params = $retention + { 'expectations' => $expectations, 'endpoints' => $endpoints }
    run_task('nest::retain_update_health', 'localhost', $retain_params + { 'action' => 'check' })
  }
  $boot_before = run_plan('nest::host::update_boot_health',
    target       => $nodes[0],
    expectations => $expectations,
  )
  $managers = run_plan('nest::host::update_manager_health', target => $nodes[0])
  if $endpoints.empty {
    $network = undef
  } else {
    $network = run_plan('nest::host::update_network_health', target => $nodes[0], endpoints => $endpoints)
  }
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
  $network_identity = $network == undef or (
    $network['schema'] == 1 and $network['kind'] == 'nest_update_network_health' and
    $network['acceptance_recorded'] == false and $network['hostname'] == $boot_before['hostname'] and
    $network['boot_id'] == $boot_before['boot_id']
  )
  $bound = $boot_identity and $manager_identity and $network_identity
  $healthy = $bound and $boot_before['result'] == 'pass' and $managers['result'] == 'pass' and
    ($network == undef or $network['result'] == 'pass')
  $outcome = $healthy ? {
    true    => 'pass',
    default => 'fail',
  }
  $outcome_report = {
    'schema'               => 1,
    'kind'                 => 'nest_update_health',
    'result'               => $outcome,
    'observations_bound'   => $bound,
    'boot_before'          => $boot_before,
    'managers'             => $managers,
    'network'              => $network,
    'network_requested'    => !$endpoints.empty,
    'boot_after'           => $boot_after,
    'acceptance_recorded'  => false,
  }
  if $retention != undef {
    $retained = run_task('nest::retain_update_health', 'localhost', $retain_params + {
      'action' => 'retain',
      'report' => $outcome_report.to_json,
    })
    return($outcome_report + { 'retained_report' => $retained.results[0].value })
  }
  return($outcome_report)
}
