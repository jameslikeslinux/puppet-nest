class nest::unifi_video {
  include '::nest'
  include '::nest::docker'

  docker_network { 'video':
    ensure  => present,
    driver  => 'macvlan',
    subnet  => '172.22.3.0/24',
    gateway => '172.22.3.1',
    options => "parent=bond0.1003",
  }

  docker_volume { 'unifi-video':
    ensure => present,
  }

  $cpuset = $::nest::availcpus_expanded.join(',')

  docker::run { 'unifi-video':
    image            => 'iamjamestl/unifi-video',
    net              => 'video',
    dns              => '172.22.3.1',
    volumes          => 'unifi-video:/var/lib/unifi-video',
    extra_parameters => [
      "--cpuset-cpus ${cpuset}",
      '--ip 172.22.3.2',
      '--cap-add SYS_ADMIN',
      '--cap-add DAC_READ_SEARCH',
      '--sysctl net.ipv4.ip_unprivileged_port_start=0',
    ],
    service_provider => 'systemd',
    stop_wait_time   => 30,
    require          => [
      Docker_network['video'],
      Docker_volume['unifi-video'],
    ],
  }
}
