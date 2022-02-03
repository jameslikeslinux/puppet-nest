class nest::base::firewall {
  $ignore = ['CNI-', 'KUBE-', 'LIBVIRT_', 'f2b-sshd', 'flannel']

  $first_boot_ruleset = @(FIRST_BOOT)
    *filter
    :INPUT ACCEPT [0:0]
    :FORWARD ACCEPT [0:0]
    :OUTPUT ACCEPT [0:0]
    COMMIT
    | FIRST_BOOT

  package { 'net-firewall/iptables':
    ensure => installed,
  }
  ->
  file { [
    '/var/lib/iptables/rules-save',
    '/var/lib/ip6tables/rules-save',
  ]:
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $first_boot_ruleset,
    replace => false,
  }

  ['iptables', 'ip6tables'].each |$i| {
    file { "/sbin/${i}-save":
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      content => epp('nest/firewall/iptables-save.epp', { 'command' => $i, 'ignore' => $ignore }),
      require => Package['net-firewall/iptables'],
    }
  }

  # Replacing the save command above breaks eselect-iptables.
  # Manage the things eselect would manage here.
  file { [
    '/sbin/iptables',
    '/sbin/iptables-restore',
    '/sbin/iptables-xml',
    '/sbin/ip6tables',
    '/sbin/ip6tables-restore',
  ]:
    ensure  => link,
    target  => 'xtables-legacy-multi',
    require => Package['net-firewall/iptables'],
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


  File['/sbin/iptables', '/sbin/ip6tables']
  -> Firewallchain <||>
  ~> [Service['iptables-store'], Service['ip6tables-store']]

  File['/sbin/iptables']
  -> Firewall <| provider == iptables or provider == undef |>
  ~> Service['iptables-store']

  File['/sbin/ip6tables']
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
