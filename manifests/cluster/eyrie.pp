class nest::cluster::eyrie {
  Service <| title == 'openvpn-client@nest' |> {
    enable => false,
  }

  firewalld_rich_rule { 'falcon':
    ensure => present,
    zone   => 'kubernetes',
    source => '172.22.4.2',
    action => accept,
  }
}
