class nest::profile::base::fs {
  package { 'net-fs/nfs-utils':
    ensure => installed,
  }

  if $::nest::fileserver {
    service { 'nfs-server':
      enable  => true,
      require => Package['net-fs/nfs-utils'],
    }

    service { 'zfs-share':
      enable  => true,
      require => Package['sys-fs/zfs'],
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
