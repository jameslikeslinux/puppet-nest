class nest::profile::base::zfs {
  package { 'sys-fs/zfs':
    ensure => installed,
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

  unless $facts['virtual'] == 'lxc' {
    # ZFS likes to have a little extra headroom on low memory systems
    sysctl { 'vm.min_free_kbytes':
      value  => '32768',
      target => '/etc/sysctl.d/nest.conf',
    }

    # Not strictly ZFS related, though our swap is on ZFS, but this
    # seems to improve stability in low memory conditions, counterintuitively.
    sysctl { 'vm.swappiness':
      value  => '10',
      target => '/etc/sysctl.d/nest.conf',
    }
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

  file { '/etc/sudoers.d/10_zfssnap':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "zfssnap ALL=NOPASSWD: /sbin/zfs, /sbin/zpool\n",
    require => Package['app-admin/sudo'],
  }

  file { '/usr/sbin/zfs-auto-snapshot':
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/nest/zfs/zfs-auto-snapshot.sh',
  }

  $zfs_auto_snapshot_service_content = @(EOT)
    [Unit]
    Description=ZFS %I auto snapshot

    [Service]
    Environment=ZFS_SNAP_KEEP_frequent=4 ZFS_SNAP_KEEP_hourly=24 ZFS_SNAP_KEEP_daily=31 ZFS_SNAP_KEEP_weekly=8 ZFS_SNAP_KEEP_monthly=12
    Type=oneshot
    ExecStart=/usr/sbin/zfs-auto-snapshot --verbose --label=%i --keep=${ZFS_SNAP_KEEP_%i} //
    | EOT

  file { '/etc/systemd/system/zfs-auto-snapshot@.service':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $zfs_auto_snapshot_service_content,
    notify  => Exec['zfs-systemctl-daemon-reload'],
  }

  $zfs_auto_snapshot_timer_frequencies = {
    'frequent' => '*:0/15',
    'hourly'   => 'hourly',
    'daily'    => 'daily',
    'weekly'   => 'weekly',
    'monthly'  => 'monthly',
  }

  $zfs_auto_snapshot_timer_frequencies.each |$frequency, $calendar| {
    $zfs_auto_snapshot_timer_content = @("EOT")
      [Unit]
      Description=ZFS %I auto snapshot timer

      [Timer]
      OnCalendar=${calendar}

      [Install]
      WantedBy=timers.target
    | EOT

    file { "/etc/systemd/system/zfs-auto-snapshot@${frequency}.timer":
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => $zfs_auto_snapshot_timer_content,
      notify  => Exec['zfs-systemctl-daemon-reload'],
    }

    service { "zfs-auto-snapshot@${frequency}.timer":
      enable  => true,
      require => Exec['zfs-systemctl-daemon-reload'],
    }
  }

  exec { 'zfs-systemctl-daemon-reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
  }
}
