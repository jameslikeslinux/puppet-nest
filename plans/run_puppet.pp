# Initiate and wait for a Puppet run
#
# @param targets A list of targets to run Puppet on
# @param build Toggle additional build functionality in the Puppet run
plan nest::run_puppet (
  TargetSpec $targets,
  Optional[Enum['kernel']] $build = undef,
) {
  if $build {
    $env = { 'FACTER_build' => $build }
  } else {
    $env = {}
  }

  run_script('nest/scripts/run_puppet.sh', $targets, 'Run Puppet via systemd', {
    '_env_vars' => $env,
    '_run_as'   => 'root',
  })
}
