class profile::role::cachefiles {
    fstab::fs { '/dev/zvol/rpool/fscache':
        mountpoint => '/var/cache/fscache',
        type       => 'ext4',
        options    => 'user_xattr,discard',
    }

    class { '::cachefiles': }
}
