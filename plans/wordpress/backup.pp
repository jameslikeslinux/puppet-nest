# Backup a Wordpress instance
#
# @param targets Wordpress host
# @param name Instance name
# @param db_host Database host
# @param wp_root Path to directory containing 'wp-content'
plan nest::wordpress::backup (
  TargetSpec $targets,
  String $name,
  Optional[String] $db_host = 'localhost',
  Optional[String] $wp_root = '/srv/wordpress',
) {
  $password = lookup('nest::service::wordpress::database_passwords')[$name]

  run_plan('nest::mariadb::backup', {
    'targets'     => get_targets($targets),
    'host'        => $db_host,
    'name'        => $name,
    'user'        => $name,
    'password'    => Sensitive($password),
    'destination' => "/nest/backup/${name}/wordpress.sql",
  })

  $backup_cmd = [
    'rsync', '-av', '--delete',
    "${wp_root}/wp-content/",
    "falcon:/nest/backup/${name}/wp-content",
  ].flatten.shellquote

  run_command($backup_cmd, $targets, 'rsync')
}
