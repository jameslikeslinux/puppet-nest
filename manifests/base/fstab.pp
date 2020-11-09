class nest::base::fstab {
  $hostname = regsubst($::trusted['certname'], '\..*', '')

  $boot_vfstype = $::nest::bootloader ? {
    'systemd' => 'vfat',
    default   => 'ext2',
  }

  $specs = {
    'boot'    => [
      "set 1/spec PARTLABEL=${hostname}-boot",
      'set 1/file /boot',
      "set 1/vfstype ${boot_vfstype}",
      'set 1/opt defaults',
      'set 1/dump 0',
      'set 1/passno 2',
    ],

    'efi'     => [
      "set 2/spec PARTLABEL=${hostname}-efi",
      'set 2/file /efi',
      "set 2/vfstype vfat",
      'set 2/opt defaults',
      'set 2/dump 0',
      'set 2/passno 2',
    ],

    'swap'    => [
      "set 3/spec /dev/zram0",
      'set 3/file none',
      'set 3/vfstype swap',
      'set 3/opt pri',
      'set 3/opt/value 10',
      'set 3/dump 0',
      'set 3/passno 0',
    ],

    'var'     => [
      'set 4/spec none',
      'set 4/file /var',
      'set 4/vfstype none',
      'set 4/opt[1] fake',
      'set 4/opt[2] x-systemd.requires',
      'set 4/opt[2]/value zfs-mount.service',
      'set 4/dump 0',
      'set 4/passno 0',
    ],

    'nest-fscache' => [
      "set 5/spec LABEL=${hostname}-fscache",
      'set 5/file /var/cache/fscache',
      'set 5/vfstype ext4',
      'set 5/opt[1] defaults',
      'set 5/opt[2] discard',
      'set 5/dump 0',
      'set 5/passno 2',

      "set 6/spec ${::nest::nestfs_hostname}:/nest",
      'set 6/file /nest',
      'set 6/vfstype nfs',
      'set 6/opt[1] noauto',
      'set 6/opt[2] fsc',
      'set 6/opt[3] x-systemd.automount',
      'set 6/opt[4] x-systemd.requires',
      'set 6/opt[4]/value openvpn-client@nest.service',
      'set 6/opt[5] x-systemd.requires',
      'set 6/opt[5]/value cachefilesd.service',
      'set 6/dump 0',
      'set 6/passno 0',
    ],

    'nest-nocache' => [
      "set 6/spec ${::nest::nestfs_hostname}:/nest",
      'set 6/file /nest',
      'set 6/vfstype nfs',
      'set 6/opt[1] noauto',
      'set 6/opt[2] x-systemd.automount',
      'set 6/opt[3] x-systemd.requires',
      'set 6/opt[3]/value openvpn-client@nest.service',
      'set 6/dump 0',
      'set 6/passno 0',
    ],
  }

  if $facts['live'] {
    $fstab = $specs['nest-nocache']
  } elsif $::platform == 'beagleboneblack' {
    $fstab = $specs['boot'] + $specs['swap'] + $specs['var'] + $specs['nest-nocache']
  } elsif $::platform in ['pinebookpro', 'raspberrypi'] {
    $fstab = $specs['boot'] + $specs['swap'] + $specs['var'] + $specs['nest-fscache']
  } elsif $::nest::nestfs_hostname == "${hostname}.nest" {
    $fstab = $specs['boot'] + $specs['efi'] + $specs['swap'] + $specs['var']
  } elsif $::nest::bootloader == 'systemd' {
    $fstab = $specs['boot'] + $specs['efi'] + $specs['swap'] + $specs['var'] + $specs['nest-fscache']
  } else {
    $fstab = $specs['boot'] + $specs['swap'] + $specs['var'] + $specs['nest-fscache']
  }

  augeas { 'fstab':
    context => '/files/etc/fstab',
    changes => ['rm *[spec]'] + $fstab
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
      notify  => Nest::Lib::Systemd_reload['fstab'],
    ;
  }

  ::nest::lib::systemd_reload { 'fstab': }
}
