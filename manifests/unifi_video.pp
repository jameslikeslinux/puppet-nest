class nest::unifi_video {
  include '::nest'
  include '::nest::docker'

  nest::srv { 'unifi-video': }

  file {
    default:
      ensure => directory,
      owner  => 'ubnt',
      group  => 'ubnt',
    ;

    '/srv/unifi-video':
      mode    => '0750',
      require => Nest::Srv['unifi-video'],
    ;

    [
      '/srv/unifi-video/data',
    ]:
      mode => '0755',
    ;

    '/srv/unifi-video/data/system.properties':
      ensure => file,
      mode   => '0644',
    ;
  }

  file_line {
    default:
      require => File['/srv/unifi-video/data/system.properties'],
      notify  => Docker::Run['unifi-video'],
      path    => '/srv/unifi-video/data/system.properties',
    ;

    'app.http.port':
      line  => 'app.http.port=80',
      match => '^app\.http\.port=',
    ;
  }

  docker_network { 'cams':
    ensure  => present,
    driver  => 'macvlan',
    subnet  => '172.22.3.0/24',
    gateway => '172.22.3.1',
    options => "parent=bond0.1003",
  }

  $cpuset = $::nest::availcpus_expanded.join(',')

  docker::run { 'unifi-video':
    image            => 'pducharme/unifi-video-controller',
    net              => 'cams',
    dns              => '172.22.3.1',
    env              => [
      'PUID=1002',
      'PGID=1002',
      'TZ=America/New_York',
    ],
    volumes          => ['/srv/unifi-video:/var/lib/unifi-video'],
    extra_parameters => [
      "--cpuset-cpus=${cpuset}",
      '--ip=172.22.3.2',
      '--cap-add=NET_BIND_SERVICE',
    ],
    service_provider => 'systemd',
    require          => [
      Docker_network['cams'],
      File['/srv/unifi-video'],
    ],
  }
}
