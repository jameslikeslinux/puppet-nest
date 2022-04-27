class nest::service::plex {
  nest::lib::container { 'plex':
    image   => 'mauimauer/spritsail-plex',
    env     => ['SUID=1001', 'SGID=1001'],
    network => 'host',
    tmpfs   => ['/transcode'],
    volumes => [
      '/srv/plex/config:/config',
      '/dev/dri:/dev/dri',
      '/nest/movies:/movies:ro',
      '/nest/tv:/tv:ro',
    ],
  }

  firewalld_service { 'plex':
    ensure => present,
  }
}
