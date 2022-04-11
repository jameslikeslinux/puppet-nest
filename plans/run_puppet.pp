# Initiate and wait for a Puppet run
#
# @param targets A list of targets to run Puppet on
# @param build Toggle additional build functionality in the Puppet run
plan nest::run_puppet (
  TargetSpec $targets,
  Optional[Enum['kernel']] $build               = undef,
  Boolean                  $skip_module_rebuild = false,
) {
  if $build {
    $build_env = { 'FACTER_build' => $build }
  } else {
    $build_env = {}
  }

  if $skip_module_rebuild {
    $skip_env = { 'FACTER_skip_module_rebuild' => 1 }
  } else {
    $skip_env = {}
  }

  run_script('nest/scripts/run_puppet.sh', $targets, 'Run Puppet via systemd', {
    _env_vars => $build_env + $skip_env,
    _run_as   => 'root',
  })
}
