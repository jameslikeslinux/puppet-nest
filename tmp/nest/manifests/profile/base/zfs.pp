class nest::profile::base::zfs {
  package { 'sys-fs/zfs':
    ensure => installed,
  }

  service { 'zfs.target':
    enable  => true,
    require => Package['sys-fs/zfs'],
  }

  # ZFS likes to have a little extra headroom on low memory systems
  sysctl { 'vm.min_free_kbytes':
    value => '32768',
  }
}
