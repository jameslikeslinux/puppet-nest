class nest::profile::base::fstab {
  $hostname = regsubst($::trusted['certname'], '\..*', '')

  $boot_vfstype = $::nest::bootloader ? {
    systemd => 'vfat',
    default => 'ext2',
  }

  # XXX: Improve this
  if $::nest::live {
    $base_changes = [
      'rm *[spec]',
    ]

    $nfs_changes = [
      "set 1/spec ${::nest::nestfs_hostname}:/nest",
      'set 1/file /nest',
      'set 1/vfstype nfs',
      'set 1/opt[1] noauto',
      'set 1/opt[2] x-systemd.automount',
      'set 1/opt[3] x-systemd.requires',
      'set 1/opt[3]/value openvpn-client@nest.service',
      'set 1/dump 0',
      'set 1/passno 0',
    ]
  } else {
    $base_changes = [
      'rm *[spec]',

      # XXX: Support /boot on mdadm
      "set 1/spec PARTLABEL=${hostname}-boot",
      'set 1/file /boot',
      "set 1/vfstype ${boot_vfstype}",
      'set 1/opt defaults',
      'set 1/dump 0',
      'set 1/passno 2',

      "set 2/spec LABEL=${hostname}-swap",
      'set 2/file none',
      'set 2/vfstype swap',
      'set 2/opt discard',
      'set 2/dump 0',
      'set 2/passno 0',

      'set 3/spec none',
      'set 3/file /var',
      'set 3/vfstype none',
      'set 3/opt[1] fake',
      'set 3/opt[2] x-systemd.requires',
      'set 3/opt[2]/value zfs-mount.service',
      'set 3/dump 0',
      'set 3/passno 0',
    ]

    $nfs_changes = [
      "set 4/spec LABEL=${hostname}-fscache",
      'set 4/file /var/cache/fscache',
      'set 4/vfstype ext4',
      'set 4/opt[1] defaults',
      'set 4/opt[2] discard',
      'set 4/dump 0',
      'set 4/passno 0',

      "set 5/spec ${::nest::nestfs_hostname}:/nest",
      'set 5/file /nest',
      'set 5/vfstype nfs',
      'set 5/opt[1] noauto',
      'set 5/opt[2] fsc',
      'set 5/opt[3] x-systemd.automount',
      'set 5/opt[4] x-systemd.requires',
      'set 5/opt[4]/value openvpn-client@nest.service',
      'set 5/dump 0',
      'set 5/passno 0',
    ]
  }

  $changes = $::nest::nestfs_hostname ? {
    "${hostname}.nest" => $base_changes,
    default            => $base_changes + $nfs_changes,
  }

  augeas { 'fstab':
    context => '/files/etc/fstab',
    changes => $changes,
  }

  # XXX: Hide harmless error at shutdown when trying to unmount /var due to
  # journald still writing to /var/log/journal
  # See: https://github.com/systemd/systemd/issues/867
  $var_lazy_unmount = @(END_OVERRIDE)
    [Mount]
    LazyUnmount=yes
    | END_OVERRIDE

  file {
    default:
      mode  => '0644',
      owner => 'root',
      group => 'root',
    ;

    '/etc/systemd/system/var.mount.d':
      ensure => directory,
    ;

    '/etc/systemd/system/var.mount.d/lazyunmount.conf':
      content => $var_lazy_unmount,
      notify  => Nest::Systemd_reload['fstab'],
    ;
  }

  ::nest::systemd_reload { 'fstab': }
}
