class nest::unifi_protect {
  include '::nest'
  include '::nest::docker'

  docker_network { 'video':
    ensure => absent,
  }

  docker::run { 'unifi-video':
    ensure => absent,
    image  => 'iamjamestl/unifi-video',
  }

  docker::run { 'unifi-protect':
    ensure => absent,
    image  => 'iamjamestl/unifi-protect',
  }
}
