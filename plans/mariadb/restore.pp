# Restore a MariaDB database
#
# @param targets Database server
# @param name Database name
# @param user Database user
# @param password Database password
# @param source Path to dump file
# @param host Database host
plan nest::mariadb::restore (
  TargetSpec $targets,
  String $name,
  String $user,
  Sensitive $password,
  String $source,
  String $host = 'localhost',
) {
  $restore_cmd = [
    'mysql', '-h', $host, '-u', $user, $name,
  ].flatten.shellquote

  run_command("${restore_cmd} < ${source.shellquote}", $targets, 'mysql', {
    _env_vars => { 'MYSQL_PWD' => $password.unwrap },
  })
}
