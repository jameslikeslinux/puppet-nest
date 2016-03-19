class nest::profile::base::zfs {
  package { 'sys-fs/zfs':
    ensure => installed,
  }

  service { 'zfs.target':
    enable  => true,
    require => Package['sys-fs/zfs'],
  }
}
