class nest::tool::buildah {
  package_accept_keywords { 'app-emulation/skopeo':
    version => '=1.1.1',
  }
  ->
  package { 'app-emulation/buildah':
    ensure => installed,
  }
}
