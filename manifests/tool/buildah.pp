class nest::tool::buildah {
  nest::lib::package { 'app-containers/buildah':
    ensure => installed,
  }
}
