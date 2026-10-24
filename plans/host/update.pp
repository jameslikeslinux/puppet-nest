# Update the operating system
#
# @param $targets Nodes to update
# @param $reset Update using reset method
# @param $reboot Reboot the system after updating
# @param $run_puppet Run Puppet to complete update (only if rebooted)
# @param $mode Legacy execution, planning, stored transaction observation or explicit preparation
# @param $policy Complete wave policy for plan/observe/prepare modes
# @param $preparation Exact per-host native transaction, root generation and capacity policy paths
# @param $observations Exact per-host stored transaction identities for read-only status
# @param $output_dir Existing canonical supervisor directory for retained reports
# @param $maintenance Exact per-controller survivor/storage/physical admission inputs for preparation
plan nest::host::update (
  TargetSpec                                   $targets,
  Boolean                                      $reset        = true,
  Boolean                                      $reboot       = false,
  Boolean                                      $run_puppet   = true,
  Enum['legacy', 'plan', 'observe', 'prepare'] $mode         = 'legacy',
  Optional[Hash]                               $policy       = undef,
  Optional[Hash]                               $preparation  = undef,
  Optional[Hash]                               $observations = undef,
  Optional[Stdlib::Absolutepath]               $output_dir   = undef,
  Optional[Hash]                               $maintenance  = undef,
) {
  if $mode in ['prepare', 'observe'] {
    if $policy == undef or $output_dir == undef or $reboot or !$reset {
      fail_plan('Transaction modes require policy, output_dir, reset=true and reboot=false', 'nest/update-prepare-inputs')
    }
    if $mode == 'prepare' {
      if $preparation == undef or $observations != undef {
        fail_plan('Prepare mode requires preparation and refuses observation inputs', 'nest/update-prepare-inputs')
      }
      $input_task = 'nest::update_prepare_inputs'
      $inputs = $preparation
      $result_kind = 'nest_update_preparation'
    } else {
      if $observations == undef or $preparation != undef {
        fail_plan('Observe mode requires observations and refuses preparation inputs', 'nest/update-observe-inputs')
      }
      $input_task = 'nest::update_observe_inputs'
      $inputs = $observations
      $result_kind = 'nest_update_observation'
    }
    $nodes = get_targets($targets)
    $bound = run_task($input_task, 'localhost', {
      'policy'  => $policy,
      'targets' => $nodes.map |$node| { $node.name },
      'inputs'  => $inputs,
    }).results[0].value
    $controllers = $nodes.filter |$node| { $node.name in ['control1', 'control2', 'control3'] }.map |$node| { $node.name }
    if $mode == 'prepare' and !$controllers.empty {
      if $maintenance == undef or $maintenance.keys.sort != $controllers.sort or
        !$maintenance.values.all |$entry| {
          $entry =~ Hash and $entry.keys.sort == ['advertisers', 'ceph_fsid', 'client', 'physical_domains', 'survivor'] and
            $entry['ceph_fsid'] =~ Pattern[/\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/]
        } {
        fail_plan('Controller preparation requires exact complete per-controller maintenance inputs', 'nest/maintenance-scope')
      }
      if $bound['waves'].any |$wave| { $wave.any |$name| { $name in $controllers } and $wave.length != 1 } {
        fail_plan('Controller preparation must be isolated from every concurrent host preparation', 'nest/maintenance-wave')
      }
      # Validate every controller before preparing any host. Repeat immediately
      # before each affected native command: an earlier sample is not a lease.
      $controllers.each |$name| {
        run_plan('nest::kubernetes::check_control_plane_maintenance', $maintenance[$name] + { 'target' => $name })
      }
    } elsif $maintenance != undef {
      fail_plan('Maintenance inputs apply only to controller preparation', 'nest/maintenance-scope')
    }
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
        if $mode == 'prepare' and $name in $controllers {
          run_plan('nest::kubernetes::check_control_plane_maintenance', $maintenance[$name] + { 'target' => $name })
        }
        $native = run_command($bound['commands'][$name].shellquote, $node, 'Run exact native transaction command', {
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
        if $mode == 'prepare' and (!$native.ok or $receipt['state'] != 'prepared') {
          fail_plan('Preparation failed or did not produce a prepared receipt; inspect retained state, never replay automatically', 'nest/update-prepare-failed')
        }
        if $mode == 'observe' and (!$native.ok or $receipt['observation_retained'] != true) {
          fail_plan('Native status did not produce a retained live observation', 'nest/update-observe-failed')
        }
        $receipt
      }
    }
    return({
      'kind'                => $result_kind,
      'schema'              => 1,
      'policy_sha256'       => $bound['policy_sha256'],
      'waves'               => $waves,
      'reboot_eligible'     => [],
      'acceptance_recorded' => false,
    })
  }
  if $preparation != undef or $observations != undef or $output_dir != undef or $maintenance != undef {
    fail_plan('Transaction inputs require their explicit prepare or observe mode', 'nest/update-prepare-inputs')
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
  $legacy_nodes = get_targets($targets)
  if $legacy_nodes.any |$node| { $node.name =~ Pattern[/\A[^.]*-console(?:\.|\z)/] } {
    fail_plan('Recovery consoles are excluded from operating system updates; no host in this selection was updated', 'nest/update-excluded-console')
  }
  if $legacy_nodes.any |$node| { $node.name in ['control1', 'control2', 'control3'] } {
    fail_plan('Legacy updates cannot admit a control-plane outage; use explicit bound preparation and maintenance policy', 'nest/maintenance-scope')
  }
  if $reset {
    $verb = 'reset'
  } else {
    $verb = 'update'
  }

  # Fail the plan on any preparation error. Never replay an ambiguous reset
  # with legacy --resume, or allow a failed target into the reboot phase.
  run_command("nest ${verb}", $legacy_nodes, "${verb.capitalize} the operating system")

  if $reboot {
    $legacy_names = $legacy_nodes.map |$node| { $node.name }
    run_plan('nest::host::reboot', $legacy_names, _description => 'Reboot the system')

    if $run_puppet {
      run_plan('nest::puppet::run', $legacy_names, _description => 'Run Puppet to complete update')
    }
  }
}
