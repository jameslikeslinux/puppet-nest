class nest::tool::buildah {
  package { [
    'app-containers/buildah',
    'app-containers/netavark',
  ]:
    ensure => installed,
  }
}
