class nest::profile::base::fs {
  package { 'net-fs/nfs-utils':
    ensure => installed,
  }

  if $::nest::server == true {
    service { 'nfs-server':
      enable  => true,
      require => Package['net-fs/nfs-utils'],
    }
  } elsif !$::nest::live {
    package { 'sys-fs/cachefilesd':
      ensure => installed,
    }

    service { 'cachefilesd':
      enable  => true,
      require => Package['sys-fs/cachefilesd'],
    }
  }
}
