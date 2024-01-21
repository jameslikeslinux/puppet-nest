# Restore a Wordpress instance
#
# @param targets Wordpress host
# @param name Instance name
# @param db_host Database host
# @param wp_root Path to directory containing 'wp-content'
plan nest::wordpress::restore (
  TargetSpec $targets,
  String $name,
  Optional[String] $db_host = 'localhost',
  Optional[String] $wp_root = '/srv/wordpress',
) {
  $password = lookup('nest::service::wordpress::database_passwords')[$name]

  run_plan('nest::mariadb::restore', {
    'targets'  => $targets,
    'host'     => $db_host,
    'name'     => $name,
    'user'     => $name,
    'password' => Sensitive($password),
    'source'   => "/nest/backup/${name}/wordpress.sql",
  })

  $restore_cmd = [
    'rsync', '-av', '--delete',
    '--exclude', 'wordpress.sql',
    "falcon:/nest/backup/${name}/",
    $wp_root,
  ].flatten.shellquote

  run_command($restore_cmd, $targets, 'rsync')
}
