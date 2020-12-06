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

  nest::lib::port_forward { 'gitlab ssh':
    proto           => tcp,
    from_port       => 22,
    to_port         => 2222,
    source_ip4      => '104.156.227.40',
    destination_ip4 => '172.22.0.1',
  }

  nest::lib::reverse_proxy {
    default:
      ip => ['104.156.227.40', '2001:19f0:300:2005::40'],
    ;

    'gitlab.james.tl':
      destination     => '172.22.0.1:8080',
      encoded_slashes => true,
      websockets      => true,
    ;

    'registry.gitlab.james.tl':
      destination => '172.22.0.1:5050',
    ;

    'requests.thesatelliteoflove.net':
      destination   => 'ombi.nest',
      serveraliases => ['requests.heloandnala.net'],
    ;

    'vault.thesatelliteoflove.net':
      destination => '127.0.0.1:1003',
      websockets  => '127.0.0.1:3012',
    ;
  }
}
