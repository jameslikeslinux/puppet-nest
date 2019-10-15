class nest::unifi_protect {
  include '::nest'
  include '::nest::docker'

  docker_network { 'video':
    ensure  => present,
    driver  => 'macvlan',
    subnet  => '172.22.3.0/24',
    gateway => '172.22.3.1',
    options => "parent=bond0.1003",
  }

  docker_volume { [
    'unifi-protect',
    'unifi-protect-postgresql',
  ]:
    ensure => present,
  }

  $cpuset = $::nest::availcpus_expanded.join(',')

  docker::run { 'unifi-video':
    ensure => absent,
    image  => 'iamjamestl/unifi-video',
    before => Docker::Run['unifi-protect'],
  }

  docker::run { 'unifi-protect':
    image            => 'unifi-protect',
    net              => 'video',
    dns              => '172.22.3.1',
    volumes          => [
      'unifi-protect:/srv/unifi-protect',
      'unifi-protect-postgresql:/var/lib/postgresql',
    ],
    extra_parameters => [
      "--cpuset-cpus ${cpuset}",
      '--ip 172.22.3.2',
      '--tmpfs /srv/unifi-protect/temp',
    ],
    service_provider => 'systemd',
    stop_wait_time   => 60,
    require          => [
      Docker_network['video'],
      Docker_volume['unifi-protect', 'unifi-protect-postgresql'],
    ],
  }
}
