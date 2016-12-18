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

  group { 'zfssnap':
    gid => '5000',  # last pool version ;)
  }

  user { 'zfssnap':
    uid     => '5000',
    gid     => 'zfssnap',
    home    => '/var/lib/zfssnap',
    comment => 'ZFS Auto Snapshot',
    shell   => '/bin/zsh',
    require => Package['app-shells/zsh'],
  }

  file { '/var/lib/zfssnap':
    ensure => directory,
    mode   => '0755',
    owner  => 'zfssnap',
    group  => 'zfssnap',
  }

  vcsrepo { '/var/lib/zfssnap':
    ensure   => latest,
    provider => git,
    source   => 'https://github.com/iamjamestl/zfssnap.git',
    revision => 'master',
    user     => 'zfssnap',
    require  => File['/var/lib/zfssnap'],
  }
}
