# Backup a Vaultwarden instance
#
# @param targets Vaultwarden host
# @param name Instance name
# @param db_host Database host
# @param srv_root Path to directory containing 'data'
plan nest::vaultwarden::backup (
  TargetSpec $targets,
  String $name,
  Optional[String] $db_host  = 'localhost',
  Optional[String] $srv_root = '/srv/vaultwarden',
) {
  $password = lookup('nest::service::bitwarden::database_password')

  run_plan('nest::mariadb::backup', {
    'targets'     => $targets,
    'host'        => $db_host,
    'name'        => $name,
    'user'        => $name,
    'password'    => Sensitive($password),
    'destination' => "/nest/backup/${name}/vaultwarden.sql",
  })

  $backup_cmd = [
    'rsync', '-av', '--delete',
    '--exclude', 'vaultwarden.sql',
    "${srv_root}/",
    "falcon:/nest/backup/${name}",
  ].flatten.shellquote

  run_command($backup_cmd, $targets, 'rsync')
}
