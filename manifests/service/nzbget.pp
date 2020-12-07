class nest::service::nzbget {
  # Required for nzbget user
  include 'nest'

  nest::lib::srv { [
    'nzbget',
    'nzbget/downloads',
  ]: }
  ->
  file {
    default:
      ensure => directory,
      mode   => '0755',
      owner  => 'nzbget',
      group  => 'media',
    ;

    [
      '/srv/nzbget',
      '/srv/nzbget/config',
      '/srv/nzbget/downloads',
    ]:
      # use defaults
    ;

    '/srv/nzbget/downloads/completed':
      mode => '0775',
    ;
  }
  ->
  nest::lib::container { 'nzbget':
    image      => 'linuxserver/nzbget',
    dns        => '172.22.0.1',
    dns_search => 'nest',
    env        => ['PUID=6789', 'PGID=1001', 'TZ=America/New_York'],
    publish    => ['6789:6789'],
    volumes    => [
      '/srv/nzbget/config:/config',
      '/srv/nzbget/downloads:/downloads',
      '/nest/downloads/nzbget/watch:/downloads/nzb',
    ],
  }
}
