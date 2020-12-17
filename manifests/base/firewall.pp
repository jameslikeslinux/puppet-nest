class nest::base::firewall {
  $ignore = ['CNI-', 'DOCKER', 'LIBVIRT_']

  package { 'net-firewall/iptables':
    ensure => installed,
  }

  ['iptables', 'ip6tables'].each |$i| {
    $save_content = @("SAVE"/$)
      #!/bin/sh
      [ -e /run/.containerenv ] || /sbin/xtables-legacy-multi ${i}-legacy-save | /bin/grep -v ${ignore.join('\|').shellquote}
      | SAVE

    file { "/sbin/${i}-save":
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      content => $save_content,
      require => Package['net-firewall/iptables'],
    }
  }


  file { [
    '/etc/systemd/system/iptables-store.service.d',
    '/etc/systemd/system/ip6tables-store.service.d',
  ]:
    ensure  => absent,
    recurse => true,
    force   => true,
  }
  ~>
  nest::lib::systemd_reload { 'firewall': }
  ->
  service { [
    'iptables-store',
    'iptables-restore',
    'ip6tables-store',
    'ip6tables-restore',
  ]:
    enable => true,
  }


  Package['net-firewall/iptables']
  -> Firewallchain <||>
  ~> [Service['iptables-store'], Service['ip6tables-store']]

  Package['net-firewall/iptables']
  -> Firewall <| provider == iptables or provider == undef |>
  ~> Service['iptables-store']

  Package['net-firewall/iptables']
  -> Firewall <| provider == ip6tables |>
  ~> Service['ip6tables-store']



  #
  # Default ruleset
  # Manage standard chains
  #
  firewallchain {
    default:
      purge  => true,

      # This parameter is still necessary despite the change to the save command
      # because it purges resources instantiated before the catalog is executed,
      # i.e., before the save command is managed.  That matters after the
      # package manager reverts the save command on updates.
      ignore => $ignore,
    ;

    # Block inbound connections
    [
      'INPUT:filter:IPv4',
      'INPUT:filter:IPv6',
    ]:
      policy => drop,
    ;

    # Disable forwarding
    [
      'FORWARD:filter:IPv4',
      'FORWARD:filter:IPv6',
    ]:
      policy => drop,
    ;

    # Allow outbound connections
    [
      'OUTPUT:filter:IPv4',
      'OUTPUT:filter:IPv6',
    ]:
      policy => accept,
    ;

    # Allow NAT
    [
      'PREROUTING:nat:IPv4',
      'PREROUTING:nat:IPv6',
      'INPUT:nat:IPv4',
      'INPUT:nat:IPv6',
      'OUTPUT:nat:IPv4',
      'OUTPUT:nat:IPv6',
      'POSTROUTING:nat:IPv4',
      'POSTROUTING:nat:IPv6',
    ]:
      policy => accept,
    ;
  }

  # Allow all local traffic
  firewall {
    default:
      proto   => all,
      iniface => 'lo',
      action  => accept,
    ;

    '000 loopback (v4)':
      provider => iptables,
    ;

    '000 loopback (v6)':
      provider => ip6tables,
    ;
  }

  # Track and allow existing connections
  firewall {
    default:
      proto  => all,
      state  => ['RELATED', 'ESTABLISHED'],
      action => accept,
    ;

    '010 related established (v4)':
      provider => iptables,
    ;

    '010 related established (v6)':
      provider => ip6tables,
    ;
  }

  # Allow ping and other control messages
  firewall {
    default:
      action => accept,
    ;

    '011 icmp (v4)':
      proto    => icmp,
      provider => iptables,
    ;

    '011 icmp (v6)':
      proto    => ipv6-icmp,
      provider => ip6tables,
    ;
  }
}
