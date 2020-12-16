class nest::service::sonarr {
  # Required for sonarr user
  include 'nest'

  nest::lib::srv { 'sonarr':
    mode  => '0755',
    owner => 'sonarr',
    group => 'media',
  }
  ->
  file { '/srv/sonarr/config':
    ensure => directory,
    mode   => '0755',
    owner  => 'sonarr',
    group  => 'media',
  }
  ->
  nest::lib::container { 'sonarr':
    image   => 'linuxserver/sonarr',
    dns     => '172.22.0.1',
    env     => ['PUID=8989', 'PGID=1001', 'TZ=America/New_York'],
    publish => ['8989:8989'],
    volumes => [
      '/srv/sonarr/config:/config',
      '/srv/nzbget/downloads:/downloads',
      '/nest/tv:/tv',
    ],
  }
}
