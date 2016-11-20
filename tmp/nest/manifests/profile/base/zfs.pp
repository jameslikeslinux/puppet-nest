class nest::profile::base::zfs {
  package { 'sys-fs/zfs':
    ensure => installed,
  }

  # See: https://github.com/zfsonlinux/zfs/blob/master/etc/systemd/system/50-zfs.preset.in
  service { [
    'zfs-import-cache.service',
    'zfs-mount.service',
    'zfs-share.service',
    'zfs-zed.service',
    'zfs.target',
  ]:
    enable  => true,
    require => Package['sys-fs/zfs'],
  }

  # ZFS likes to have a little extra headroom on low memory systems
  sysctl { 'vm.min_free_kbytes':
    value => '32768',
  }

  # Not strictly ZFS related, though our swap is on ZFS, but this
  # seems to improve stability in low memory conditions, counterintuitively.
  sysctl { 'vm.swappiness':
    value => '10',
  }
}
