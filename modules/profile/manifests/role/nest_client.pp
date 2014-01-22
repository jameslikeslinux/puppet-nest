class profile::role::nest_client {
    $cachefiles = cachefiles in $profile::base::roles

    class { 'autofs': }

    autofs::mount { 'nest':
        map      => 'direct',
        key      => '/nest',
        location => 'hawk:/nest',
        options  => $cachefiles ? {
            true    => ['fsc'],
            default => undef,
        }
    }
}
