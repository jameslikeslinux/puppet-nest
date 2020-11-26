class nest::base::firewall {
  package { 'net-firewall/iptables':
    ensure => installed,
  }

  # Doing anything related to iptables inside an ARM chroot fails
  if $facts['os']['architecture'] =~ /^(arm|aarch64)/ {
    if $facts['virtual'] == 'lxc' {
      file { [
        '/sbin/iptables-save',
        '/sbin/ip6tables-save',
      ]:
        ensure  => link,
        target  => '/bin/true',
        require => Package['net-firewall/iptables'],
      }
      ->
      Firewall <| |>
    } else {
      file { [
        '/sbin/iptables-save',
        '/sbin/ip6tables-save',
      ]:
        ensure  => link,
        target  => 'xtables-legacy-multi',
        require => Package['net-firewall/iptables'],
      }
      ->
      Firewall <| |>
    }
  }


  # Keep the 'store' services alive after exit and don't run them at shutdown so
  # that Puppet and only Puppet triggers them.  The idea is that ephemeral rules
  # should not be saved just because the system is shutting down; Puppet has the
  # final say in what gets saved.
  $service_dropin = @(SVC_DROPIN)
    [Service]
    RemainAfterExit=yes
    | SVC_DROPIN

  file {
    default:
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      require => Package['net-firewall/iptables'],
      notify  => Nest::Lib::Systemd_reload['firewall'],
    ;

    [
      '/etc/systemd/system/iptables-store.service.d',
      '/etc/systemd/system/ip6tables-store.service.d',
    ]:
      ensure => directory,
    ;

    [
      '/etc/systemd/system/iptables-store.service.d/10-remain-after-exit.conf',
      '/etc/systemd/system/ip6tables-store.service.d/10-remain-after-exit.conf',
    ]:
      content => $service_dropin,
    ;
  }

  nest::lib::systemd_reload { 'firewall': }

  service { [
    'iptables-store',
    'ip6tables-store',
  ]:
    ensure  => running,
    enable  => false,
    require => Nest::Lib::Systemd_reload['firewall'],
  }

  service { [
    'iptables-restore',
    'ip6tables-restore',
  ]:
    enable => true,
  }



  # The firewall and firewallchain types define autorequires for package and
  # service resources with Red Hat and Debian names, so it has to be done
  # explicitly for Gentoo here.
  Package['net-firewall/iptables']
  -> Firewallchain <| |>
  ~> [Service['iptables-store'], Service['ip6tables-store']]

  Package['net-firewall/iptables']
  -> Firewall <| provider == iptables or provider == undef |>
  ~> Service['iptables-store']

  Package['net-firewall/iptables']
  -> Firewall <| provider == ip6tables |>
  ~> Service['ip6tables-store']



  #
  # Default ruleset
  #
  firewallchain {
    [
      'INPUT:filter:IPv4',
      'INPUT:filter:IPv6',
    ]:
      policy => drop,
      purge  => !str2bool($::chroot),
      ignore => [
        '-i virbr\d+',
        '-j LIBVIRT_INP',
        '-j f2b-sshd',
      ],
    ;

    # Disable forwarding by default
    [
      'FORWARD:filter:IPv4',
      'FORWARD:filter:IPv6',
    ]:
      policy => drop,
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
