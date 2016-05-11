class nest::profile::base::fstab {
  $hostname = regsubst($::trusted['certname'], '\..*', '')

  augeas { 'fstab':
    context => '/files/etc/fstab',
    changes => [
      "rm *[spec]",

      "set 1/spec LABEL=${hostname}-boot",
      "set 1/file /boot",
      "set 1/vfstype ext2",
      "set 1/opt defaults",
      "set 1/dump 0",
      "set 1/passno 2",

      "set 2/spec /dev/zvol/${hostname}/swap",
      "set 2/file none",
      "set 2/vfstype swap",
      "set 2/opt discard",
      "set 2/dump 0",
      "set 2/passno 0",

      "set 3/spec none",
      "set 3/file /var",
      "set 3/vfstype none",
      "set 3/opt[1] fake",
      "set 3/opt[2] x-systemd.requires",
      "set 3/opt[2]/value zfs-mount.service",
      "set 3/dump 0",
      "set 3/passno 0",
    ],
  }
}
