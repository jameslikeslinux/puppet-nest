class nest::service::plex {
  nest::lib::container { 'plex':
    ensure  => absent,
    image   => 'plexinc/pms-docker',
    env     => ['PLEX_UID=32400', 'PLEX_GID=1001', 'TZ=America/New_York'],
    network => 'host',
    tmpfs   => ['/transcode'],
    volumes => [
      '/srv/plex/config:/config',
      '/nest/movies:/movies',
      '/nest/tv:/tv',
    ],
  }

  firewalld_service { 'plex':
    ensure => present,
  }
}
