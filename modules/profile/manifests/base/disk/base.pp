class profile::base::disk::base {
    $disk_id        = $profile::base::disk_id
    $disk_mirror_id = $profile::base::disk_mirror_id

    class { 'zfs': }

    if $profile::base::remote_backup == true {
        class { 'zfs::backup':
            remote_host    => 'hawk',
            remote_dataset => "nest/backup/nodes/${clientcert}",
        } 
    } else {
        class { 'zfs::backup': }
    }

    if $virtual == 'physical' {
        class { 'smart': }
    }

    fstab::fs { 'boot':
        device     => "${disk_id}1",
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

    grub::install { $disk_id: }
}
