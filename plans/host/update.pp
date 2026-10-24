# Update the operating system
#
# @param $targets Nodes to update
# @param $reset Update using reset method
# @param $reboot Reboot the system after updating
# @param $run_puppet Run Puppet to complete update (only if rebooted)
# @param $mode Legacy execution or read-only exact-policy wave planning
# @param $policy Complete wave policy; required only for plan mode
plan nest::host::update (
  TargetSpec             $targets,
  Boolean                $reset      = true,
  Boolean                $reboot     = false,
  Boolean                $run_puppet = true,
  Enum['legacy', 'plan'] $mode       = 'legacy',
  Optional[Hash]         $policy     = undef,
) {
  if $mode == 'plan' {
    if $policy == undef or $reboot or !$reset {
      fail_plan('Wave planning requires policy, reset=true and reboot=false', 'nest/update-wave-policy')
    }
    $nodes = get_targets($targets)
    $wave_plan = run_task('nest::update_wave_plan', 'localhost', {
      'policy'  => $policy,
      'targets' => $nodes.map |$node| { $node.name },
    })
    return($wave_plan.results[0].value)
  }
  if $policy != undef {
    fail_plan('Wave policy is planning-only; it cannot authorize legacy execution', 'nest/update-wave-policy')
  }
  if $reset {
    $verb = 'reset'
  } else {
    $verb = 'update'
  }

  # Fail the plan on any preparation error. Never replay an ambiguous reset
  # with legacy --resume, or allow a failed target into the reboot phase.
  run_command("nest ${verb}", $targets, "${verb.capitalize} the operating system")

  if $reboot {
    run_plan('nest::host::reboot', $targets, _description => 'Reboot the system')

    if $run_puppet {
      run_plan('nest::puppet::run', $targets, _description => 'Run Puppet to complete update')
    }
  }
}
