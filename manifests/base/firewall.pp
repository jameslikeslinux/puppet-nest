class nest::base::firewall {
  # Doing anything related to iptables inside an ARM chroot fails
  if $facts['os']['architecture'] =~ /^(arm|aarch64)/ {
    if $facts['virtual'] == 'lxc' {
      file { [
        '/sbin/iptables-save',
        '/sbin/ip6tables-save',
      ]:
        ensure  => link,
        target  => '/bin/true',
        require => Class['firewall'],
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
        require => Class['firewall'],
      }
      ->
      Firewall <| |>
    }
  }

  class { '::firewall':
    # The Gentoo iptables systemd services are just oneshots
    ensure       => stopped,
    service_name => 'iptables-restore',
  }

  # Gentoo systemd services use a different save file
  File <| title == '/var/lib/iptables/rules-save6' |> {
    path => '/var/lib/ip6tables/rules-save',
  }

  service { [
    'iptables-store',
    'ip6tables-restore',
    'ip6tables-store',
  ]:
    enable => false,
  }


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
