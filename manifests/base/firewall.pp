class nest::base::firewall {
  class { 'firewalld':
    default_zone => 'drop',
  }

  Service <| title == firewalld |> {
    ensure => undef,
  }

  firewalld_zone {
    default:
      purge_rich_rules => true,
      purge_services   => true,
      purge_ports      => true,
    ;

    'drop':
      interfaces => [$facts['networking']['primary']],
    ;

    'trusted':
      interfaces => ['tun0'],
    ;
  }


  #
  # Cleanup
  #
  service { [
    'iptables-store',
    'iptables-restore',
    'ip6tables-store',
    'ip6tables-restore',
  ]:
    enable => false,
  }

  file { [
    '/var/lib/iptables/rules-save',
    '/var/lib/ip6tables/rules-save',
  ]:
    ensure => absent,
  }
}
