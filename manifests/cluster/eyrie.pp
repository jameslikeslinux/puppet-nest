class nest::cluster::eyrie {
  Service <| title == 'openvpn-client@nest' |> {
    enable  => false,
    ensure  => stopped,
    require => Class['nest::base::network'],
  }

  firewalld_rich_rule { 'falcon':
    ensure => present,
    zone   => 'home',
    source => '172.22.1.10',
    action => accept,
  }
}
