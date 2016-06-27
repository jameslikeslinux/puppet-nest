class nest::node::media {
  include '::nest::docker'

  zfs { 'srv':
    name       => "${::trusted['certname']}/srv",
    mountpoint => '/srv',
  }

  zfs { 'srv/nzbget':
    name    => "${::trusted['certname']}/srv/nzbget",
    require => Zfs['srv'],
  }

  file {
    default:
      mode    => '0755',
      owner   => 'nzbget',
      group   => 'media';

    '/srv/nzbget':
      require => Zfs['srv/nzbget'];

    [
      '/srv/nzbget/config',
      '/srv/nzbget/downloads',
      '/srv/nzbget/downloads/incomplete',
    ]:
      # use defaults
      ;

    '/srv/nzbget/downloads/complete':
      mode    => '0775';
  }

  Docker::Run {
    service_provider => 'systemd',
  }

  docker::run { 'nzbget':
    image   => 'linuxserver/nzbget',
    ports   => '6789',
    env     => ['PUID=6789', 'PGID=1001'],
    volumes => [
      '/srv/nzbget/config:/config',
      '/srv/nzbget/downloads:/downloads',
      '/nest',
    ],
    require => [
      File['/srv/nzbget/config'],
      File['/srv/nzbget/downloads'],
    ],
  }
}
