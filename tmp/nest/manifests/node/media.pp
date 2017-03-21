class nest::node::media {
  include '::nest::apache'
  include '::nest::docker'

  zfs { 'srv':
    name       => "${::trusted['certname']}/srv",
    mountpoint => '/srv',
  }

  zfs { 'srv/couchpotato':
    name       => "${::trusted['certname']}/srv/couchpotato",
    mountpoint => '/srv/couchpotato',
    require    => Zfs['srv'],
  }

  zfs { 'srv/nzbget':
    name       => "${::trusted['certname']}/srv/nzbget",
    mountpoint => '/srv/nzbget',
    require    => Zfs['srv'],
  }

  zfs { 'srv/sonarr':
    name       => "${::trusted['certname']}/srv/sonarr",
    mountpoint => '/srv/sonarr',
    require    => Zfs['srv'],
  }

  zfs { 'srv/transmission':
    name       => "${::trusted['certname']}/srv/transmission",
    mountpoint => '/srv/transmission',
    require    => Zfs['srv'],
  }

  file {
    default:
      ensure  => directory,
      mode    => '0755',
      owner   => 'couchpotato',
      group   => 'media';

    '/srv/couchpotato':
      require => Zfs['srv/couchpotato'];

    '/srv/couchpotato/config':
      # use defaults
      ;
  }

  file {
    default:
      ensure  => directory,
      mode    => '0755',
      owner   => 'nzbget',
      group   => 'media';

    '/srv/nzbget':
      require => Zfs['srv/nzbget'];

    [
      '/srv/nzbget/config',
      '/srv/nzbget/downloads',
    ]:
      # use defaults
      ;

    '/srv/nzbget/downloads/completed':
      mode    => '0775';
  }

  file {
    default:
      ensure  => directory,
      mode    => '0755',
      owner   => 'sonarr',
      group   => 'media';

    '/srv/sonarr':
      require => Zfs['srv/sonarr'];

    '/srv/sonarr/config':
      # use defaults
      ;
  }

  file {
    default:
      ensure  => directory,
      mode    => '0755',
      owner   => 'transmission',
      group   => 'media';

    '/srv/transmission':
      require => Zfs['srv/transmission'];

    [
      '/srv/transmission/config',
      '/srv/transmission/downloads',
    ]:
      # use defaults
      ;
  }

  Docker::Run {
    service_provider => 'systemd',
    depend_services  => 'remote-fs.target',
  }

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

  docker::run { 'transmission':
    image   => 'linuxserver/transmission',
    ports   => ['9091:9091', '51413:51413', '51413:51413/udp'],
    env     => ['PUID=9091', 'PGID=1001', 'TZ=America/New_York'],
    volumes => [
      '/srv/transmission/config:/config',
      '/srv/transmission/downloads:/downloads',
      '/nest/downloads/transmission/complete:/downloads/complete',
      '/nest/downloads/transmission/watch:/watch',
    ],
    require => [
      File['/srv/transmission/config'],
      File['/srv/transmission/downloads'],
    ],
  }

  apache::vhost { 'couchpotato.nest':
    port       => '80',
    docroot    => '/var/www/couchpotato.nest',
    proxy_pass => [
      { 'path' => '/', 'url' => 'http://localhost:5050/' },
    ],
  }

  apache::vhost { 'nzbget.nest':
    port       => '80',
    docroot    => '/var/www/nzbget.nest',
    proxy_pass => [
      { 'path' => '/', 'url' => 'http://localhost:6789/' },
    ],
  }

  apache::vhost { 'sonarr.nest':
    port       => '80',
    docroot    => '/var/www/sonarr.nest',
    proxy_pass => [
      { 'path' => '/', 'url' => 'http://localhost:8989/' },
    ],
  }

  apache::vhost { 'transmission.nest':
    port       => '80',
    docroot    => '/var/www/transmission.nest',
    proxy_pass => [
      { 'path' => '/', 'url' => 'http://localhost:9091/' },
    ],
  }

  firewall { '100 docker to apache':
    iniface => 'docker0',
    proto   => tcp,
    dport   => 80,
    state   => 'NEW',
    action  => accept,
  }

  firewall { '100 transmission (tcp)':
    proto  => tcp,
    dport  => 51413,
    state  => 'NEW',
    action => accept,
  }

  firewall { '100 transmission (udp)':
    proto  => udp,
    dport  => 51413,
    state  => 'NEW',
    action => accept,
  }

  firewall { '100 transmission (tcp6)':
    proto    => tcp,
    dport    => 51413,
    state    => 'NEW',
    action   => accept,
    provider => ip6tables,
  }

  firewall { '100 transmission (udp6)':
    proto    => udp,
    dport    => 51413,
    state    => 'NEW',
    action   => accept,
    provider => ip6tables,
  }
}
