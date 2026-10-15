class nest::service::nzbget {
  # Required for media user
  include 'nest'

  nest::lib::srv { [
    'nzbget',
    'nzbget/downloads',
  ]:
    mode  => '0755',
    owner => 'media',
    group => 'media',
  }
  ->
  file {
    default:
      ensure => directory,
      mode   => '0755',
      owner  => 'media',
      group  => 'media',
    ;

    '/srv/nzbget/config':
      # use defaults
    ;

    '/srv/nzbget/downloads/completed':
      mode => '0775',
    ;
  }
  ->
  nest::lib::container { 'nzbget':
    image   => 'linuxserver/nzbget',
    env     => ['PUID=1001', 'PGID=1001', 'TZ=America/New_York'],
    publish => ['6789:6789'],
    volumes => [
      '/srv/nzbget/config:/config',
      '/srv/nzbget/downloads:/downloads',
      '/nest/downloads/nzbget/watch:/downloads/nzb',
    ],
  }

  # The application creates its configuration on the real host, not in a
  # Stage 3 container where nest::lib::container omits the runtime service.
  unless $facts['is_container'] {
    file_line {
      'nzbget-write-log':
        path   => '/srv/nzbget/config/nzbget.conf',
        line   => 'WriteLog=rotate',
        match  => '^WriteLog=',
        notify => Service['container-nzbget'],
      ;

      'nzbget-rotate-log':
        path   => '/srv/nzbget/config/nzbget.conf',
        line   => 'RotateLog=3',
        match  => '^RotateLog=',
        notify => Service['container-nzbget'],
      ;
    }
    File['/srv/nzbget/config'] -> File_line['nzbget-write-log', 'nzbget-rotate-log'] -> Nest::Lib::Container['nzbget']
  }
}
