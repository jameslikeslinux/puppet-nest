class nest::profile::base::fs {
  if $::nest::server {
    package { 'net-fs/nfs-utils':
      ensure => installed,
    }

    service { 'nfs-server':
      enable  => true,
      require => Package['net-fs/nfs-utils'],
    }
  }
}
