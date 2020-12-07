class nest::service::radarr {
  # Required for radarr user
  include 'nest'

  nest::lib::srv { 'radarr': }
  ->
  file { [
    '/srv/radarr',
    '/srv/radarr/config',
  ]:
    ensure => directory,
    mode   => '0755',
    owner  => 'radarr',
    group  => 'media',
  }
  ->
  nest::lib::container { 'radarr':
    image   => 'linuxserver/radarr',
    dns     => '172.22.0.1',
    env     => ['PUID=7878', 'PGID=1001', 'TZ=America/New_York'],
    publish => ['7878:7878'],
    volumes => [
      '/srv/radarr/config:/config',
      '/srv/nzbget/downloads:/downloads',
      '/nest/movies:/movies',
    ],
  }
}
