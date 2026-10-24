# Observe exact postboot identities; this never records transaction acceptance.
plan nest::host::update_boot_health (
  TargetSpec            $target,
  Hash[String, String]  $expectations,
) {
  $nodes = get_targets($target)
  if $nodes.length != 1 {
    fail_plan('Boot observation requires exactly one host', 'nest/update-boot-health-target')
  }
  $result = run_task('nest::update_boot_health', $nodes[0], {
    'expectations' => $expectations,
    '_run_as'      => 'root',
  })
  return $result.first.value
}
