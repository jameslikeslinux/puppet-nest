# Restore a Vaultwarden instance
#
# @param targets Vaultwarden host
# @param service Vaultwarden service
# @param db_host Database host
# @param srv_root Path to directory containing 'data'
# @param restore Safety gate
plan nest::vaultwarden::restore (
  TargetSpec       $targets,
  String           $service,
  Optional[String] $db_host  = 'localhost',
  Optional[String] $srv_root = '/srv/vaultwarden',
  Boolean          $restore  = false,
) {
  if $restore {
    $password = lookup('nest::service::bitwarden::database_password')

    run_plan('nest::mariadb::restore', {
      'targets'  => $targets,
      'host'     => $db_host,
      'name'     => $service,
      'user'     => $service,
      'password' => Sensitive($password),
      'source'   => "/nest/backup/${service}/vaultwarden.sql",
    })

    $restore_cmd = [
      'rsync', '-av', '--delete',
      '--exclude', 'vaultwarden.sql',
      "falcon:/nest/backup/${service}/",
      $srv_root,
    ].flatten.shellquote

    run_command($restore_cmd, $targets, 'rsync', {
      '_run_as' => 'root',
    })
  }
}
