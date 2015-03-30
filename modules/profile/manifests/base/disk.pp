class profile::base::disk {
    class { '::zfs': }

    if $::profile::base::remote_backup == true {
        class { '::zfs::backup':
            remote_host => 'hawk',
            remote_dataset => "nest/backup/nodes/${clientcert}",
        }
    } else {
        class { '::zfs::backup': }
    }

    if $virtual == 'physical' {
        class { '::smart': }
    }

    if $profile::base::boot_decrypt {
        class { '::crypt': }
    }

    if is_array($profile::base::boot_disk) and size($profile::base::boot_disk) > 1 {
        class { '::mdraid':
            mailaddr => 'root',
        }
    }

    fstab::fs { 'boot':
        device     => "LABEL=boot",
        mountpoint => '/boot',
        type       => 'ext2',
        options    => 'noatime',
        dump       => 1,
        pass       => 2
    }

    fstab::fs { 'swap':
        device     => 'LABEL=swap',
        mountpoint => 'none',
        type       => 'swap',
        options    => 'discard',
    }
}
