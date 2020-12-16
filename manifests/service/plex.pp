class nest::service::plex {
  # Required for plex user
  include 'nest'

  nest::lib::srv { 'plex':
    mode  => '0755',
    owner => 'plex',
    group => 'media',
  }
  ->
  file { '/srv/plex/config':
    ensure => directory,
    mode   => '0755',
    owner  => 'plex',
    group  => 'media',
  }
  ->
  nest::lib::container { 'plex':
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
}
