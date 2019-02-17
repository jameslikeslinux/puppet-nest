class nest::unifi {
  include '::nest'
  include '::nest::docker'

  docker_network { 'mgmt':
    ensure  => present,
    driver  => 'macvlan',
    subnet  => '172.22.2.0/24',
    gateway => '172.22.2.1',
    options => "parent=bond0.1002",
  }

  docker_volume { 'unifi':
    ensure => present,
  }

  $cpuset = $::nest::availcpus_expanded.join(',')

  docker::run { 'unifi':
    image            => 'iamjamestl/unifi',
    net              => 'mgmt',
    dns              => '172.22.2.1',
    volumes          => 'unifi:/unifi',
    extra_parameters => [
      "--cpuset-cpus ${cpuset}",
      '--ip 172.22.2.3',
      '--cap-add DAC_READ_SEARCH',
      '--cap-add NET_BIND_SERVICE',
      '--cap-add SETGID',
      '--cap-add SETUID',
    ],
    service_provider => 'systemd',
    stop_wait_time   => 30,
    require          => [
      Docker_network['mgmt'],
      Docker_volume['unifi'],
    ],
  }
}
