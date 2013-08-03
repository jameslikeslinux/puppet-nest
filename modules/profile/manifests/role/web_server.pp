class profile::role::web_server {
    $lamp_server   = lamp_server in $profile::base::roles
    $thestaticvoid = thestaticvoid in $profile::base::roles

    $modules = [
        $lamp_server ? {
            true    => ['fcgid', 'php'],
            default => '',
        },

        $thestaticvoid ? {
            true    => 'proxy',
            default => '',
        },
    ]

    class { 'apache':
        modules => flatten($modules),
    }
}
