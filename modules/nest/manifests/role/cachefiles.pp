class nest::role::cachefiles {
    fstab::fs { 'LABEL=fscache':
        mountpoint => '/var/cache/fscache',
        type       => 'ext4',
        options    => 'user_xattr,discard',
    }

    class { '::cachefiles': }
}
