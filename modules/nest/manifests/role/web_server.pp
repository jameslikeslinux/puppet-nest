class nest::role::web_server {
    $lamp_server   = lamp_server in $nest::roles
    $thestaticvoid = thestaticvoid in $nest::roles

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

    iptables::accept { 'http':
        port     => 80,
        protocol => tcp,
    }

    iptables::accept { 'https':
        port     => 443,
        protocol => tcp,
    }
}
