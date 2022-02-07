class nest::node::falcon {
  firewall {
    '012 multicast':
      proto   => udp,
      pkttype => 'multicast',
      action  => accept,
    ;

    '100 podman to apache':
      iniface => 'cni-podman0',
      proto   => tcp,
      dport   => [80, 443],
      state   => 'NEW',
      action  => accept,
    ;

    '100 podman to distccd':
      iniface => 'cni-podman0',
      proto   => tcp,
      dport   => 3632,
      state   => 'NEW',
      action  => accept,
    ;

    '100 podman to dnsmasq':
      iniface => 'cni-podman0',
      proto   => udp,
      dport   => 53,
      state   => 'NEW',
      action  => accept,
    ;

    '100 podman to smtp':
      iniface => 'cni-podman0',
      proto   => udp,
      dport   => 25,
      state   => 'NEW',
      action  => accept,
    ;

    '100 plex':
      proto  => tcp,
      dport  => 32400,
      state  => 'NEW',
      action => accept,
    ;

    '100 puppet from local network':
      chain  => 'FORWARD',
      source => "${facts['networking']['network']}/${facts['networking']['netmask']}",
      proto  => tcp,
      dport  => 8140,
      state  => 'NEW',
      action => accept,
    ;
  }

  nest::lib::toolchain {
    [
      'aarch64-unknown-linux-gnu',
      'armv7a-unknown-linux-gnueabihf',
    ]:
      # use defaults
    ;

    'arm-none-eabi':
      gcc_only => true,
    ;
  }
}
