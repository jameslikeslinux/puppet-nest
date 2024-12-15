# Backup a Vaultwarden instance
#
# @param targets Vaultwarden host
# @param service Vaultwarden service
# @param db_host Database host
# @param srv_root Path to directory containing 'data'
plan nest::vaultwarden::backup (
  TargetSpec $targets,
  String $service,
  Optional[String] $db_host  = 'localhost',
  Optional[String] $srv_root = '/srv/vaultwarden',
) {
  $password = lookup('nest::service::bitwarden::database_password')

  run_plan('nest::mariadb::backup', {
    'targets'     => $targets,
    'host'        => $db_host,
    'name'        => $service,
    'user'        => $service,
    'password'    => Sensitive($password),
    'destination' => "/nest/backup/${service}/vaultwarden.sql",
  })

  $backup_cmd = [
    'rsync', '-av', '--delete',
    '--exclude', 'vaultwarden.sql',
    "${srv_root}/",
    "falcon:/nest/backup/${service}",
  ].flatten.shellquote

  run_command($backup_cmd, $targets, 'rsync', {
    '_run_as' => 'root',
  })
}
