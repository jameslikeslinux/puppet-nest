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
      dport   => 80,
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

    '100 plex':
      proto  => tcp,
      dport  => 32400,
      state  => 'NEW',
      action => accept,
    ;
  }

  nest::lib::reverse_proxy {
    default:
      ssl => false,
      ip  => '172.22.0.1',
    ;

    'nzbget.nest':
      destination => '127.0.0.1:6789',
    ;

    'ombi.nest':
      destination => '127.0.0.1:3579',
    ;

    'plex.nest':
      destination => '127.0.0.1:32400',
      websockets  => true,
    ;

    'radarr.nest':
      destination => '127.0.0.1:7878',
    ;

    'sonarr.nest':
      destination => '127.0.0.1:8989',
    ;
  }
}
