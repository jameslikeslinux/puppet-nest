# Restore a WordPress instance
#
# @param targets WordPress host
# @param service WordPress service
# @param db_host Database host
# @param wp_root Path to directory containing 'wp-content'
# @param restore Safety gate
plan nest::wordpress::restore (
  TargetSpec       $targets,
  String           $service,
  Optional[String] $db_host = 'localhost',
  Optional[String] $wp_root = '/srv/wordpress',
  Boolean          $restore = false,
) {
  if $restore {
    $password = lookup('nest::service::wordpress::database_passwords')[$service]

    run_plan('nest::mariadb::restore', {
      'targets'  => $targets,
      'host'     => $db_host,
      'name'     => $service,
      'user'     => $service,
      'password' => Sensitive($password),
      'source'   => "/nest/backup/${service}/wordpress.sql",
    })

    $restore_cmd = [
      'rsync', '-av', '--delete',
      '--exclude', 'wordpress.sql',
      '--filter', 'P wp-config.php',
      "falcon:/nest/backup/${service}/",
      $wp_root,
    ].flatten.shellquote

    run_command($restore_cmd, $targets, 'rsync')
  }
}
