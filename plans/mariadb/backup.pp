# Backup a MariaDB database
#
# @param targets Database server
# @param name Database name
# @param user Database user
# @param password Database password
# @param destination Path to dump file
# @param host Database host
plan nest::mariadb::backup (
  TargetSpec $targets,
  String $name,
  String $user,
  Sensitive $password,
  String $destination,
  String $host = 'localhost',
) {
  $backup_cmd = [
    'mysqldump', '-h', $host, '-u', $user, $name,
  ].flatten.shellquote

  run_command("${backup_cmd} > ${destination.shellquote}", $targets, 'mysqldump', {
    _env_vars => { 'MYSQL_PWD' => $password.unwrap },
  })
}
