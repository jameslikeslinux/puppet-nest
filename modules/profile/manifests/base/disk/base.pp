class profile::base::disk::base {
    $disk_id        = $profile::base::disk_id
    $disk_mirror_id = $profile::base::disk_mirror_id

    class { 'zfs': }
    class { 'smart': }

    fstab::fs { 'boot':
        device     => "/dev/disk/by-id/${disk_id}-part1",
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
        options    => 'sw',
    }

    grub::install { "/dev/disk/by-id/${disk_id}": }
}
