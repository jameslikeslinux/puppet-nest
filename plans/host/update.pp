# Update the operating system
#
# @param $targets Nodes to update
# @param $reset Update using reset method
# @param $reboot Reboot the system after updating
# @param $run_puppet Run Puppet to complete update (only if rebooted)
# @param $mode Legacy execution, read-only planning or explicit transaction preparation
# @param $policy Complete wave policy for plan/prepare modes
# @param $preparation Exact per-host native transaction, root generation and capacity policy paths
# @param $output_dir Existing canonical supervisor directory for preparation reports
plan nest::host::update (
  TargetSpec                        $targets,
  Boolean                           $reset       = true,
  Boolean                           $reboot      = false,
  Boolean                           $run_puppet  = true,
  Enum['legacy', 'plan', 'prepare'] $mode        = 'legacy',
  Optional[Hash]                    $policy      = undef,
  Optional[Hash]                    $preparation = undef,
  Optional[Stdlib::Absolutepath]    $output_dir  = undef,
) {
  if $mode == 'prepare' {
    if $policy == undef or $preparation == undef or $output_dir == undef or $reboot or !$reset {
      fail_plan('Preparation requires policy, preparation, output_dir, reset=true and reboot=false', 'nest/update-prepare-inputs')
    }
    $nodes = get_targets($targets)
    $bound = run_task('nest::update_prepare_inputs', 'localhost', {
      'policy'  => $policy,
      'targets' => $nodes.map |$node| { $node.name },
      'inputs'  => $preparation,
    }).results[0].value
    # Check ALL supervisor destinations before the first native reset. This is
    # read-only validation, not a promise of future disk space or writeability.
    $bound['inputs'].each |$name, $input| {
      run_task('nest::retain_update_report', 'localhost', {
        'action'      => 'check',
        'transaction' => $input['transaction'],
        'release'     => $bound['release'],
        'hostname'    => $name,
        'output_dir'  => $output_dir,
      })
    }
    $waves = $bound['waves'].map |$wave| {
      # parallelize waits for the whole wave, including retention, before the
      # next wave starts. A failure never starts the next wave or a reboot.
      parallelize($wave) |$name| {
        $node = $nodes.filter |$candidate| { $candidate.name == $name }[0]
        $native = run_command($bound['commands'][$name].shellquote, $node, 'Prepare exact native update transaction once', {
          '_run_as'       => 'root',
          '_catch_errors' => true,
        })
        $stdout = $native.results[0].value['stdout']
        # Retain a valid stopped/failed receipt too. Initialization, transport
        # or malformed-output failures refuse; they are never replayed.
        $receipt = run_task('nest::retain_update_report', 'localhost', {
          'report'      => $stdout,
          'transaction' => $bound['inputs'][$name]['transaction'],
          'release'     => $bound['release'],
          'hostname'    => $name,
          'output_dir'  => $output_dir,
        }).results[0].value
        if !$native.ok or $receipt['state'] != 'prepared' {
          fail_plan('Preparation failed or did not produce a prepared receipt; inspect retained state, never replay automatically', 'nest/update-prepare-failed')
        }
        $receipt
      }
    }
    return({
      'kind'                => 'nest_update_preparation',
      'schema'              => 1,
      'policy_sha256'       => $bound['policy_sha256'],
      'waves'               => $waves,
      'reboot_eligible'     => [],
      'acceptance_recorded' => false,
    })
  }
  if $preparation != undef or $output_dir != undef {
    fail_plan('Preparation inputs are supported only in explicit prepare mode', 'nest/update-prepare-inputs')
  }
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
