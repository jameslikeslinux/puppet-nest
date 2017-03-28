class nest::node::falcon {
  include '::nest'
  include '::nest::apache'
  include '::nest::docker'

  nest::srv { 'plex': }

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

  Docker::Run {
    service_provider => 'systemd',
  }

  $cpuset = $::nest::availcpus_expanded.join(',')

  docker::run { 'plex':
    image            => 'linuxserver/plex',
    net              => 'host',
    env              => ['VERSION=latest', 'PUID=32400', 'PGID=1001', 'TZ=America/New_York'],
    volumes          => [
      '/srv/plex/config:/config',
      '/nest/movies:/movies',
      '/nest/tv:/tv',
    ],
    extra_parameters => ["--cpuset-cpus=${cpuset}"],
    require          => File['/srv/plex/config'],
  }

  nest::revproxy { 'plex.nest':
    destination => 'http://localhost:32400/',
    ssl         => false,
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
