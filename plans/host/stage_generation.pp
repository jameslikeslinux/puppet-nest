# Transfer and seal one explicitly selected host-local root generation.
#
# @param $targets Exactly one canonical inventory hostname matching policy
# @param $policy Exact generation placement, identity, digest and transfer-budget policy
# @param $check Read-only placement/content admission by default; false explicitly copies and seals
plan nest::host::stage_generation (
  TargetSpec $targets,
  Hash       $policy,
  Boolean    $check = true,
) {
  $nodes = get_targets($targets)
  unless $nodes.length == 1 and $nodes[0].name == $policy['hostname'] and
    $nodes[0].name !~ Pattern[/\A(?:control[123]\.|[^.]*-console(?:\.|\z))/] {
    fail_plan('Generation staging requires one exact canonical non-console host', 'nest/generation-scope')
  }
  # Only public placement/digest/budget fields belong in this JSON. The helper
  # validates the complete schema and never logs file names or private content.
  $args = ['python3', '/usr/libexec/nest/transfer-generation.py', $policy.to_json]
  $command = $check ? {
    true    => $args + ['--check'],
    default => $args,
  }
  $native = run_command($command.shellquote, $nodes[0], 'Check or stage exact immutable root generation', '_run_as' => 'root')
  $report = parsejson($native.results[0].value['stdout'])
  unless $report['kind'] == 'nest_generation_transfer_report' and $report['schema'] == 1 and
    $report['policy'] == $policy and $report['read_only'] == $check and
    $report['sealed'] == !$check and $report['reset_authorized'] == false {
    fail_plan('Generation staging did not return the exact expected bound result; never replay', 'nest/generation-result')
  }
  return($report)
}
