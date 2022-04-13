class nest::base::firewall {
  class { 'firewalld':
    default_zone => 'drop',
  }

  # Don't manage the service state
  Service <| title == 'firewalld' |> {
    ensure => undef,
  }

  # Configure and purge the zones that this module uses
  firewalld_zone {
    default:
      purge_rich_rules => true,
      purge_services   => true,
      purge_ports      => true,
    ;

    'drop':
      interfaces => [$facts['networking']['primary']],
      tag        => 'default',
    ;

    'trusted':
      interfaces => ['tun0'],
      masquerade => true,
    ;
  }

  # Purge direct rules
  firewalld_direct_purge { 'rule': }


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
