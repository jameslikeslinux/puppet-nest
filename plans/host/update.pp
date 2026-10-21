# Update the operating system
#
# @param $targets Nodes to update
# @param $reset Update using reset method
# @param $reboot Reboot the system after updating
# @param $run_puppet Run Puppet to complete update (only if rebooted)
plan nest::host::update (
  TargetSpec $targets,
  Boolean    $reset      = true,
  Boolean    $reboot     = false,
  Boolean    $run_puppet = true,
) {
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
