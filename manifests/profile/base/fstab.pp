class nest::profile::base::fstab {
  $hostname = regsubst($::trusted['certname'], '\..*', '')

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
    if $nest and $nest['profile'] == 'beaglebone' {
      $efi = []
      $swap = []
      $fscache = []
    } else {
      $efi = [
        "set 2/spec PARTLABEL=${hostname}-efi",
        'set 2/file /efi',
        "set 2/vfstype vfat",
        'set 2/opt defaults',
        'set 2/dump 0',
        'set 2/passno 2',
      ]

      $swap = [
        "set 3/spec LABEL=${hostname}-swap",
        'set 3/file none',
        'set 3/vfstype swap',
        'set 3/opt discard',
        'set 3/dump 0',
        'set 3/passno 0',
      ]

      $fscache = [
        "set 10/spec LABEL=${hostname}-fscache",
        'set 10/file /var/cache/fscache',
        'set 10/vfstype ext4',
        'set 10/opt[1] defaults',
        'set 10/opt[2] discard',
        'set 10/dump 0',
        'set 10/passno 0',
      ]
    }
    $base_changes = [
      'rm *[spec]',

      $::nest::bootloader ? {
        systemd => [
          "set 1/spec PARTLABEL=${hostname}-boot",
          'set 1/file /boot',
          "set 1/vfstype vfat",
          'set 1/opt defaults',
          'set 1/dump 0',
          'set 1/passno 2',

          $efi,
        ],

        default => [
          "set 1/spec LABEL=${hostname}-boot",
          'set 1/file /boot',
          "set 1/vfstype ext2",
          'set 1/opt defaults',
          'set 1/dump 0',
          'set 1/passno 2',
        ],
      },

      $swap,

      'set 4/spec none',
      'set 4/file /var',
      'set 4/vfstype none',
      'set 4/opt[1] fake',
      'set 4/opt[2] x-systemd.requires',
      'set 4/opt[2]/value zfs-mount.service',
      'set 4/dump 0',
      'set 4/passno 0',
    ].flatten

    $nfs_changes = [
      $fscache,

      "set 11/spec ${::nest::nestfs_hostname}:/nest",
      'set 11/file /nest',
      'set 11/vfstype nfs',
      'set 11/opt[1] noauto',
      'set 11/opt[2] fsc',
      'set 11/opt[3] x-systemd.automount',
      'set 11/opt[4] x-systemd.requires',
      'set 11/opt[4]/value openvpn-client@nest.service',
      'set 11/dump 0',
      'set 11/passno 0',
    ].flatten
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
