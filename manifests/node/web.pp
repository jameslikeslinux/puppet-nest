class nest::node::web {
  include 'nest::service::bitwarden'
  include 'nest::service::mysql'

  mysql::db { 'bitwarden':
    user     => 'bitwarden',
    password => $::nest::service::bitwarden::database_password,
    host     => '%',
    before   => Class['nest::service::bitwarden'],
  }

  firewall { '100 podman to mysql':
    iniface => 'cni-podman0',
    proto   => tcp,
    dport   => 3306,
    state   => 'NEW',
    action  => accept,
    before  => Class['nest::service::bitwarden'],
  }
}
