class nest::base::zfs {
  package { 'sys-fs/zfs':
    ensure => installed,
  }

  $zfs_mount_override = @(EOF)
    [Service]
    ExecStart=
    ExecStart=/sbin/zfs mount -al
    | EOF

  file {
    default:
      mode  => '0644',
      owner => 'root',
      group => 'root',
    ;

    '/etc/systemd/system/zfs-mount.service.d':
      ensure => directory,
    ;

    '/etc/systemd/system/zfs-mount.service.d/load-key.conf':
      ensure => absent,
    ;

    '/etc/systemd/system/zfs-mount.service.d/10-load-key.conf':
      content => $zfs_mount_override,
      notify  => Nest::Lib::Systemd_reload['zfs'],
    ;
  }

  unless $facts['is_container'] or $facts['running_live'] {
    exec { 'zgenhostid':
      command => '/sbin/zgenhostid `hostid`',
      creates => '/etc/hostid',
      require => Package['sys-fs/zfs'],
      notify  => Class['::nest::base::dracut'],
    }
  }

  file { '/usr/lib/dracut/modules.d/90zfs/zfs-load-key.sh':
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    source  => 'puppet:///modules/nest/zfs/zfs-load-key.sh',
    require => Package['sys-fs/zfs'],
    notify  => Class['::nest::base::dracut'],
  }

  # On systems without ZFS root, the zfs module doesn't get loaded by dracut
  file { '/etc/modules-load.d/zfs.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "zfs\n",
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

  group { 'zfssnap':
    ensure => absent,
  }

  user { 'zfssnap':
    ensure => absent,
    before => Group['zfssnap'],
  }

  file { '/var/lib/zfssnap':
    ensure  => absent,
    recurse => true,
    force   => true,
  }

  file { '/etc/sudoers.d/10_zfssnap':
    ensure => absent,
  }

  file { '/usr/sbin/zfs-auto-snapshot':
    ensure => absent,
  }

  file { '/etc/systemd/system/zfs-auto-snapshot@.service':
    ensure => absent,
    notify => Nest::Lib::Systemd_reload['zfs'],
  }

  $zfs_auto_snapshot_timer_frequencies = {
    'frequent' => '*:0/15',
    'hourly'   => 'hourly',
    'daily'    => 'daily',
    'weekly'   => 'weekly',
    'monthly'  => 'monthly',
  }

  $zfs_auto_snapshot_timer_frequencies.each |$frequency, $calendar| {
    file { "/etc/systemd/system/zfs-auto-snapshot@${frequency}.timer":
      ensure => absent,
      notify => Nest::Lib::Systemd_reload['zfs'],
    }

    service { "zfs-auto-snapshot@${frequency}.timer":
      enable => false,
      before => Nest::Lib::Systemd_reload['zfs'],
    }
  }

  ::nest::lib::systemd_reload { 'zfs': }

  unless $facts['is_container'] or $facts['running_live'] {
    exec { 'generate-zpool-cache':
      command => "/sbin/zpool set cachefile= ${trusted['certname']}",
      creates => '/etc/zfs/zpool.cache',
    }

    # Manage swap volume properties for experimenting with workarounds listed in
    # https://github.com/openzfs/zfs/issues/7734
    zfs { "${facts['rpool']}/swap":
      compression    => 'off',
      sync           => 'standard',
      primarycache   => 'metadata',
      secondarycache => 'none',
      logbias        => 'throughput',
    }
  }
}
