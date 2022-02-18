class nest::base::firewall {
  class { 'firewalld':
    default_zone => 'drop',
  }

  # Don't manage the service state
  Service <| title == 'firewalld' |> {
    ensure => undef,
  }

  # Firewalld doesn't have to be running
  Exec <| title == 'firewalld::set_default_zone' |> {
    returns +> 252, # NOT_RUNNING see: firewall-cmd(1)
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
      masquerade => true,
    ;

    ['block', 'dmz', 'external', 'home', 'internal', 'public', 'work']:
      # Purge other built-in zones
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
