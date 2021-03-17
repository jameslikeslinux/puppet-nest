class nest::tool::buildah {
  # Can be used as a storage backend when /dev/zfs
  # and CAP_SYS_ADMIN are added to the container
  package { 'sys-fs/zfs':
    ensure => installed,
  }

  package_accept_keywords { 'app-emulation/skopeo':
    version => '=1.1.1',
  }
  ->
  package { 'app-emulation/buildah':
    ensure => installed,
  }
}
