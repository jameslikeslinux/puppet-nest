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

  file { '/etc/sudoers.d/10_zfssnap':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "zfssnap ALL=NOPASSWD: /sbin/zfs, /sbin/zpool\n",
    require => Package['app-admin/sudo'],
  }

  exec { 'zfssnap-enable-linger':
    command => '/usr/bin/loginctl enable-linger zfssnap',
    creates => '/var/lib/systemd/linger/zfssnap',
    require => [
      Vcsrepo['/var/lib/zfssnap'],
      File['/etc/sudoers.d/10_zfssnap'],
    ],
  }

  exec {
    default:
      user        => 'zfssnap',
      environment => 'XDG_RUNTIME_DIR=/run/user/5000',
      refreshonly => true;

    'zfssnap-systemd-daemon-reload':
      command   => '/usr/bin/systemctl --user daemon-reload',
      require   => Exec['zfssnap-enable-linger'],
      subscribe => Vcsrepo['/var/lib/zfssnap'];

    'zfssnap-restart-timers':
      command   => '/usr/bin/systemctl --user restart timers.target',
      subscribe => Exec['zfssnap-systemd-daemon-reload'];
  }
}
