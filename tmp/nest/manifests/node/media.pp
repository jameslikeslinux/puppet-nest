class nest::node::media {
  include '::nest::apache'
  include '::nest::docker'

  zfs { 'srv':
    name       => "${::trusted['certname']}/srv",
    mountpoint => '/srv',
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

  Docker::Run {
    service_provider => 'systemd',
    after            => 'remote-fs.target',
  }

  docker::run { 'nzbget':
    image   => 'linuxserver/nzbget',
    ports   => '6789:6789',
    env     => ['PUID=6789', 'PGID=1001'],
    volumes => [
      '/srv/nzbget/config:/config',
      '/srv/nzbget/downloads:/downloads',
      '/nest/downloads/nzbs:/downloads/nzb',
    ],
    require => [
      File['/srv/nzbget/config'],
      File['/srv/nzbget/downloads'],
    ],
  }

  docker::run { 'sonarr':
    image   => 'linuxserver/sonarr',
    ports   => '8989:8989',
    env     => ['PUID=8989', 'PGID=1001'],
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
}
