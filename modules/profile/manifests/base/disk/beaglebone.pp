class profile::base::disk::beaglebone {
    class { 'profile::base::disk::zfs': }
    class { 'zfs::smallpc': }

    fstab::fs { 'boot':
        device     => "/dev/mmcblk0p1",
        mountpoint => '/boot',
        type       => 'ext2',
        options    => 'noatime',
        dump       => 1,
        pass       => 2
    }

    fstab::fs { 'swap':
        device     => '/dev/zvol/rpool/swap',
        mountpoint => 'none',
        type       => 'swap',
        options    => 'discard',
    }
}
