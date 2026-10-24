# Transfer and seal one explicitly selected host-local root generation.
#
# @param $targets Exactly one canonical inventory hostname matching policy
# @param $policy Exact generation placement, identity, digest and transfer-budget policy
# @param $check Read-only placement/content admission by default; false explicitly copies and seals
# @param $verify_only Verify an already sealed local generation and its retained receipts without publication access
plan nest::host::stage_generation (
  TargetSpec $targets,
  Hash       $policy,
  Boolean    $check       = true,
  Boolean    $verify_only = false,
) {
  if $verify_only and !$check {
    fail_plan('Sealed generation verification requires check=true; it never transfers', 'nest/generation-mode')
  }
  $nodes = get_targets($targets)
  unless $nodes.length == 1 and $nodes[0].name == $policy['hostname'] and
    $nodes[0].name !~ Pattern[/\A(?:control[123]\.|[^.]*-console(?:\.|\z))/] {
    fail_plan('Generation staging requires one exact canonical non-console host', 'nest/generation-scope')
  }
  # Only public placement/digest/budget fields belong in this JSON. The helper
  # validates the complete schema and never logs file names or private content.
  $args = ['python3', '/usr/libexec/nest/transfer-generation.py', $policy.to_json]
  $command = $verify_only ? {
    true    => $args + ['--verify'],
    default => $check ? {
      true    => $args + ['--check'],
      default => $args,
    },
  }
  $kind = $verify_only ? {
    true    => 'nest_generation_verification_report',
    default => 'nest_generation_transfer_report',
  }
  $native = run_command($command.shellquote, $nodes[0], 'Check or stage exact immutable root generation', '_run_as' => 'root')
  $report = parsejson($native.results[0].value['stdout'])
  unless $report['kind'] == $kind and $report['schema'] == 1 and
    $report['policy'] == $policy and $report['read_only'] == $check and
    $report['sealed'] == ($verify_only or !$check) and $report['reset_authorized'] == false and
    (!$verify_only or $report['reset_capacity_admitted'] == false) {
    fail_plan('Generation staging did not return the exact expected bound result; never replay', 'nest/generation-result')
  }
  return($report)
}
