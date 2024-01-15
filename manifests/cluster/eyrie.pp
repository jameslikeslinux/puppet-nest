class nest::cluster::eyrie {
  Service <| title == 'openvpn-client@nest' |> {
    enable => false,
  }

  file { '/etc/systemd/system/openvpn-client@nest.service':
    ensure => link,
    target => '/dev/null',
  }

  # Conflicts with routing between networks
  Firewalld_zone <| title == 'internal' |> {
    sources => undef,
  }

  # Allow routing between kubernetes and Nest
  Firewalld_zone <| title == 'kubernetes' |> {
    sources +> '172.22.0.0/24',
  }

  firewalld_rich_rule { 'nest':
    ensure => present,
    zone   => 'kubernetes',
    source => '172.22.0.0/24',
    action => accept,
  }

  firewalld_rich_rule { 'falcon':
    ensure => present,
    zone   => 'kubernetes',
    source => '172.22.4.2',
    action => accept,
  }
}
