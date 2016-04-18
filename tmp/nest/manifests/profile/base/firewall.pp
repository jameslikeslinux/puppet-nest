class nest::profile::base::firewall {
  class { '::firewall':
    # The Gentoo iptables systemd services are just oneshots
    ensure       => stopped,
    service_name => 'iptables',
  }

  service { [
    'iptables-restore',
    'iptables-store',
    'ip6tables-restore',
    'ip6tables-store',
  ]:
    enable => !$::nest::libvirt,
  }

  firewallchain { 'INPUT:filter:IPv4':
    ensure => present,
    purge  => true,
    ignore => 'virbr\d+',
  }

  firewallchain { 'INPUT:filter:IPv6':
    ensure => present,
    purge  => true,
  }
}
