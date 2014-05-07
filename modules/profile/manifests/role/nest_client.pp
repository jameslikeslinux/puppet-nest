class profile::role::nest_client {
    $cachefiles = cachefiles in $profile::base::roles

    $mount_options = [
        $profile::base::nest_rwsize ? {
            undef   => [],
            default => ["rsize=${profile::base::nest_rwsize}", "wsize=${profile::base::nest_rwsize}"],
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
