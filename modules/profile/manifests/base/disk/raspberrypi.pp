class profile::base::disk::raspberrypi {
    class { 'zfs': }

    fstab::fs { 'boot':
        device     => "/dev/mmcblk0p1",
        mountpoint => '/boot',
        type       => 'auto',
        options    => 'noatime',
        dump       => 1,
        pass       => 2
    }

    fstab::fs { 'swap':
        device     => "/dev/mmcblk0p2",
        mountpoint => 'none',
        type       => 'swap',
        options    => 'sw',
    }
}
