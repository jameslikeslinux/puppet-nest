class nest::service::plex {
  # Required for plex user
  include 'nest'

  nest::lib::srv { 'plex': }
  ->
  file { [
    '/srv/plex',
    '/srv/plex/config',
  ]:
    ensure => directory,
    mode   => '0755',
    owner  => 'plex',
    group  => 'media',
  }
  ->
  nest::lib::container { 'plex':
    image      => 'plexinc/pms-docker',
    dns        => '172.22.0.1',
    dns_search => 'nest',
    env        => ['PLEX_UID=32400', 'PLEX_GID=1001', 'TZ=America/New_York'],
    network    => 'host',
    tmpfs      => ['/transcode'],
    volumes    => [
      '/srv/plex/config:/config',
      '/nest/movies:/movies',
      '/nest/tv:/tv',
    ],
  }
}
