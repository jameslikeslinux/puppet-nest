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

  Docker::Run {
    service_provider => 'systemd',
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
    after   => 'remote-fs.target',
  }

  apache::vhost { 'media.nest':
    port       => '80',
    docroot    => '/var/www/media.nest',
    proxy_pass => [
      { 'path' => '/nzbget', 'url' => 'http://localhost:6789' },
    ],
  }
}
