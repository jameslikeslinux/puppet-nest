class profile::role::nest_client {
    $cachefiles = cachefiles in $profile::base::roles

    $mount_options = [
        $profile::base::wan ? {
            true    => ["rsize=8192", "wsize=8192"],
            default => [],
        },

        $cachefiles ? {
            true    => ['fsc'],
            default => [],
        },
    ]

    class { 'autofs': }

    autofs::mount { 'nest':
        map      => 'direct',
        key      => '/nest',
        location => 'hawk:/nest',
        options  => flatten($mount_options),
    }
}
