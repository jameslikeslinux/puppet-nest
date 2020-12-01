class nest::node::falcon {
  include '::nest'
  include '::nest::service::docker'

  nest::lib::srv { [
    'nzbget',
    'nzbget/downloads',
    'ombi',
    'plex',
    'radarr',
    'sonarr',
  ]: }

  file {
    default:
      ensure => directory,
      mode   => '0755',
      owner  => 'nzbget',
      group  => 'media',
    ;

    '/srv/nzbget':
      require => Nest::Lib::Srv['nzbget'],
    ;

    [
      '/srv/nzbget/config',
      '/srv/nzbget/downloads',
    ]:
      # use defaults
    ;

    '/srv/nzbget/downloads/completed':
      mode    => '0775',
    ;
  }

  file {
    default:
      ensure => directory,
      mode   => '0755',
      owner  => 'ombi',
      group  => 'media',
    ;

    '/srv/ombi':
      require => Nest::Lib::Srv['ombi'],
    ;

    '/srv/ombi/config':
      # use defaults
    ;
  }

  file {
    default:
      ensure => directory,
      mode   => '0755',
      owner  => 'plex',
      group  => 'media',
    ;

    '/srv/plex':
      require => Nest::Lib::Srv['plex'],
    ;

    '/srv/plex/config':
      # use defaults
    ;
  }

  file {
    default:
      ensure => directory,
      mode   => '0755',
      owner  => 'radarr',
      group  => 'media',
    ;

    '/srv/radarr':
      require => Nest::Lib::Srv['radarr'],
    ;

    '/srv/radarr/config':
      # use defaults
    ;
  }

  file {
    default:
      ensure => directory,
      mode   => '0755',
      owner  => 'sonarr',
      group  => 'media',
    ;

    '/srv/sonarr':
      require => Nest::Lib::Srv['sonarr'],
    ;

    '/srv/sonarr/config':
      # use defaults
    ;
  }

  $cpuset = $::nest::availcpus_expanded.join(',')
  $cpuset_param = "--cpuset-cpus ${cpuset}"

  Docker::Run {
    dns              => '172.22.0.1',
    dns_search       => 'nest',
    extra_parameters => $cpuset_param,
    service_provider => 'systemd',
  }

  docker::run { 'nzbget':
    image   => 'linuxserver/nzbget',
    ports   => '6789:6789',
    env     => ['PUID=6789', 'PGID=1001', 'TZ=America/New_York'],
    volumes => [
      '/srv/nzbget/config:/config',
      '/srv/nzbget/downloads:/downloads',
      '/nest/downloads/nzbget/watch:/downloads/nzb',
    ],
    require => [
      File['/srv/nzbget/config'],
      File['/srv/nzbget/downloads'],
    ],
  }

  docker::run { 'ombi':
    image   => 'linuxserver/ombi',
    ports   => '3579:3579',
    env     => ['PUID=3579', 'PGID=1001', 'TZ=America/New_York'],
    volumes => [
      '/srv/ombi/config:/config',
    ],
    require => File['/srv/ombi'],
  }

  docker::run { 'plex':
    image            => 'plexinc/pms-docker',
    net              => 'host',
    env              => ['PLEX_UID=32400', 'PLEX_GID=1001', 'TZ=America/New_York'],
    volumes          => [
      '/srv/plex/config:/config',
      '/nest/movies:/movies',
      '/nest/tv:/tv',
    ],
    extra_parameters => [$cpuset_param, '--tmpfs /transcode'],
    require          => File['/srv/plex/config'],
  }

  docker::run { 'radarr':
    image   => 'linuxserver/radarr',
    ports   => '7878:7878',
    env     => ['PUID=7878', 'PGID=1001', 'TZ=America/New_York'],
    volumes => [
      '/srv/radarr/config:/config',
      '/srv/nzbget/downloads:/downloads',
      '/nest/movies:/movies',
    ],
    require => [
      File['/srv/radarr/config'],
      File['/srv/nzbget/downloads/completed'],
    ],
  }

  docker::run { 'sonarr':
    image   => 'linuxserver/sonarr',
    ports   => '8989:8989',
    env     => ['PUID=8989', 'PGID=1001', 'TZ=America/New_York'],
    volumes => [
      '/srv/sonarr/config:/config',
      '/srv/nzbget/downloads:/downloads',
      '/nest/tv:/tv',
    ],
    require => [
      File['/srv/sonarr/config'],
      File['/srv/nzbget/downloads/completed'],
    ],
  }

  nest::lib::reverse_proxy {
    default:
      ssl => false,
      ip  => '172.22.0.1',
    ;

    'nzbget.nest':
      destination => 'localhost:6789',
    ;

    'ombi.nest':
      destination => 'localhost:3579',
    ;

    'plex.nest':
      destination => 'localhost:32400',
      websockets  => ':/websockets/.*',
    ;

    'radarr.nest':
      destination => 'localhost:7878',
    ;

    'sonarr.nest':
      destination => 'localhost:8989',
    ;
  }

  firewall { '012 multicast':
    proto   => udp,
    pkttype => 'multicast',
    action  => accept,
  }

  firewall { '100 docker to apache':
    iniface => 'docker0',
    proto   => tcp,
    dport   => 80,
    state   => 'NEW',
    action  => accept,
  }

  firewall { '100 docker to dnsmasq':
    iniface => 'docker0',
    proto   => udp,
    dport   => 53,
    state   => 'NEW',
    action  => accept,
  }

  firewall { '100 plex':
    proto  => tcp,
    dport  => 32400,
    state  => 'NEW',
    action => accept,
  }

  sysctl { 'fs.inotify.max_user_watches':
    value  => '1048576',
    target => '/etc/sysctl.d/nest.conf',
  }

  nest::lib::package_use { 'media-sound/beets':
    use => ['ffmpeg', 'gstreamer', 'lastfm', 'replaygain'],
  }

  # Temporarily remove beets because it is being dropped from gentoo
  # Will reinstall after bringing the ebuild into my repo and enable Python 3.7 support
  package { 'media-sound/beets':
    ensure => absent,
  }
}
