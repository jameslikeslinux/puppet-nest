# Backup a WordPress instance
#
# @param targets WordPress host
# @param service WordPress service
# @param db_host Database host
# @param wp_root Path to directory containing 'wp-content'
plan nest::wordpress::backup (
  TargetSpec $targets,
  String $service,
  Optional[String] $db_host = 'localhost',
  Optional[String] $wp_root = '/srv/wordpress',
) {
  $password = lookup('nest::service::wordpress::database_passwords')[$service]

  run_plan('nest::mariadb::backup', {
    'targets'     => $targets,
    'host'        => $db_host,
    'name'        => $service,
    'user'        => $service,
    'password'    => Sensitive($password),
    'destination' => "/nest/backup/${service}/wordpress.sql",
  })

  $backup_cmd = [
    'rsync', '-av', '--delete',
    '--exclude', 'wordpress.sql',
    "${wp_root}/",
    "falcon:/nest/backup/${service}",
  ].flatten.shellquote

  run_command($backup_cmd, $targets, 'rsync', {
    '_run_as' => 'root',
  })
}
