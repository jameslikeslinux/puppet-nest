# Execute normal main catalogs, retaining detailed native exits without acceptance.
plan nest::host::update_catalog (
  TargetSpec                   $target,
  Optional[Hash[String, Data]] $expectations = undef,
) {
  $nodes = get_targets($target)
  if $nodes.length != 1 {
    fail_plan('Catalog convergence requires exactly one host', 'nest/update-catalog-target')
  }
  if $expectations != undef {
    $bound = run_task('nest::update_catalog_apply', $nodes[0], {
      'expectations' => $expectations,
      '_run_as'     => 'root',
    })
    return($bound.results[0].value)
  }
  # Never use a cached catalog, noop, a build fact or a tagged kernel-only apply
  # as evidence of normal served main convergence. Source identity still needs
  # independent report binding; requesting main alone does not prove its source.
  $options = {
    '_run_as'       => 'root',
    '_catch_errors' => true,
    '_env_vars'     => {
      'PUPPET_PRESERVE_DETAILED_EXIT' => 'true',
      'PUPPET_EXTRA_ARGS'            => shellquote([
        '--environment', 'main', '--no-noop', '--no-use_cached_catalog',
        '--no-usecacheonfailure', '--tags=', '--skip_tags=',
      ]),
    },
  }
  $first = run_script('nest/scripts/run_puppet.sh', $nodes[0], 'Apply normal main catalog', $options)
  $main_exit = $first.results[0].value['exit_code']
  if $main_exit in [0, 2] {
    $second = run_script('nest/scripts/run_puppet.sh', $nodes[0], 'Check unchanged main catalog repeat', $options)
    $repeat_exit = $second.results[0].value['exit_code']
  } else {
    $repeat_exit = undef
  }
  $converged = $main_exit in [0, 2] and $repeat_exit == 0
  return({
    'schema'                  => 1,
    'kind'                    => 'nest_update_catalog',
    'result'                  => $converged ? { true => 'pass', default => 'fail' },
    'main_exit'               => $main_exit,
    'repeat_exit'             => $repeat_exit,
    'repeat_attempted'        => $main_exit in [0, 2],
    'converged'               => $converged,
    'requested_environment'   => 'main',
    'served_source_verified'  => false,
    'acceptance_recorded'     => false,
  })
}
