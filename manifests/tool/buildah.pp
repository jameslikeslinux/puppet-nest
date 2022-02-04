class nest::tool::buildah {
  package_accept_keywords { 'app-containers/skopeo':
    version => '=1.1.1',
  }
  ->
  package { 'app-containers/buildah':
    ensure => installed,
  }
}
