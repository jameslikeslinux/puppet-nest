class nest::tool::buildah {
  package { 'app-containers/buildah':
    ensure => installed,
  }
}
