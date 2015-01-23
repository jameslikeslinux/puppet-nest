class profile::base::disk::base {
    $disk_id                = $profile::base::disk_id
    $disk_mirror_id         = $profile::base::disk_mirror_id
    $disk_id_no_part        = regsubst($disk_id, '^(.*?)-part', '\1')
    $disk_mirror_id_no_part = regsubst($disk_mirror_id, '^(.*?)-part', '\1')

    class { 'profile::base::disk::zfs': }

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
        options    => 'discard',
    }

    grub::install { $disk_id_no_part: }
}
