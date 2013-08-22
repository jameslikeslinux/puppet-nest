class profile::role::nest_client {
    class { 'autofs': }

    autofs::mount { 'nest':
        map      => 'direct',
        key      => '/nest',
        location => 'hawk:/nest',
    }
}
