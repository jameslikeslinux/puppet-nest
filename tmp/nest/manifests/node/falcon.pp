class nest::node::falcon {
  include '::nest'
  include '::nest::docker'

  nest::srv { [
    'couchpotato',
    'nzbget',
    'plex',
    'sonarr',
  ]: }

  file {
    default:
      ensure  => directory,
      mode    => '0755',
      owner   => 'couchpotato',
      group   => 'media',
    ;

    '/srv/couchpotato':
      require => Nest::Srv['couchpotato'],
    ;

    '/srv/couchpotato/config':
      # use defaults
    ;
  }

  file {
    default:
      ensure  => directory,
      mode    => '0755',
      owner   => 'nzbget',
      group   => 'media',
    ;

    '/srv/nzbget':
      require => Nest::Srv['nzbget'],
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
      ensure  => directory,
      mode    => '0755',
      owner   => 'plex',
      group   => 'media',
    ;

    '/srv/plex':
      require => Nest::Srv['plex'],
    ;

    '/srv/plex/config':
      # use defaults
    ;
  }

  file {
    default:
      ensure  => directory,
      mode    => '0755',
      owner   => 'sonarr',
      group   => 'media',
    ;

    '/srv/sonarr':
      require => Nest::Srv['sonarr'],
    ;

    '/srv/sonarr/config':
      # use defaults
    ;
  }

  Docker::Run {
    dns              => '172.22.2.1',
    dns_search       => 'nest',
    service_provider => 'systemd',
  }

  $cpuset = $::nest::availcpus_expanded.join(',')

  docker::run { 'couchpotato':
    image   => 'linuxserver/couchpotato',
    ports   => '5050:5050',
    env     => ['PUID=5050', 'PGID=1001', 'TZ=America/New_York'],
    volumes => [
      '/srv/couchpotato/config:/config',
      '/srv/nzbget/downloads:/downloads',
      '/nest/movies:/movies',
    ],
    require => [
      File['/srv/couchpotato/config'],
      File['/srv/nzbget/downloads/completed'],
    ],
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

  docker::run { 'plex':
    image            => 'linuxserver/plex',
    ports            => '32400:32400',
    env              => ['VERSION=latest', 'PUID=32400', 'PGID=1001', 'TZ=America/New_York'],
    volumes          => [
      '/srv/plex/config:/config',
      '/nest/movies:/movies',
      '/nest/tv:/tv',
    ],
    extra_parameters => ["--cpuset-cpus=${cpuset}"],
    require          => File['/srv/plex/config'],
  }

  docker::run { 'sonarr':
    image   => 'linuxserver/sonarr',
    ports   => '8989:8989',
    env     => ['PUID=8989', 'PGID=1001', 'TZ=America/New_York'],
    volumes => [
      '/dev/rtc:/dev/rtc:ro',
      '/srv/sonarr/config:/config',
      '/srv/nzbget/downloads:/downloads',
      '/nest/tv:/tv',
    ],
    require => [
      File['/srv/sonarr/config'],
      File['/srv/nzbget/downloads/completed'],
    ],
  }

  nest::revproxy {
    default:
      ssl => false,
    ;

    'couchpotato.nest':
      destination => 'http://localhost:5050/',
    ;

    'nzbget.nest':
      destination => 'http://localhost:6789/',
    ;

    'plex.nest':
      destination => 'http://localhost:32400/'
    ;

    'sonarr.nest':
      destination => 'http://localhost:8989/',
    ;
  }

  firewall { '012 multicast':
    proto   => udp,
    pkttype => 'multicast',
    action  => accept,
  }

  firewall { '100 crashplan':
    proto  => tcp,
    dport  => 4242,
    state  => 'NEW',
    action => accept,
  }

  firewall { '100 docker to apache':
    iniface => 'docker0',
    proto   => tcp,
    dport   => 80,
    state   => 'NEW',
    action  => accept,
  }

  firewall { '100 docker to dns':
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
    value => '1048576',
  }

  nest::portage::package_use { 'media-sound/beets':
    use => ['gstreamer', 'lastgenre', 'replaygain'],
  }

  package { 'media-sound/beets':
    ensure => installed,
  }
}
