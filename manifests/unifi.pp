class nest::unifi {
  include '::nest'
  include '::nest::docker'

  docker_network { 'mgmt':
    ensure => absent,
  }

  $cpuset = $::nest::availcpus_expanded.join(',')

  docker::run { 'unifi':
    ensure => absent,
    image  => 'iamjamestl/unifi',
  }
}
