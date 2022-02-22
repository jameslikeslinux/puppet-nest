class nest::node::web {
  include 'nest::service::bitwarden'
  include 'nest::service::mysql'

  mysql::db { 'bitwarden':
    user     => 'bitwarden',
    password => $::nest::service::bitwarden::database_password,
    host     => '%',
    before   => Class['nest::service::bitwarden'],
  }
}
