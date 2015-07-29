class nest::users {
    include private::nest::users

    #
    # Has a user.
    #
    class { 'zsh': }

    $virtalbox = virtualbox in $nest::roles
    $terminal_client = terminal_client in $nest::roles
    $desktop = desktop in $nest::roles

    $groups = [
        'wheel',

        $virtualbox ? {
            true    => 'vboxusers',
            default => [],
        },

        $terminal_client ? {
            true    => 'uucp',
            default => [],
        },

        $desktop ? {
            true    => ['audio', 'video'],
            default => [],
        },

        $nest::solaar ? {
            true    => 'plugdev',
            default => [],
        },
    ]

    $require = [
        Class['zsh'],

        $virtualbox ? {
            true    => Class['virtualbox'],
            default => [],
        },
    ]

    users::user { 'jlee':
        uid            => 1000,
        groups         => flatten($groups),
        fullname       => 'James Lee',
        shell          => '/bin/zsh',
        profile        => 'https://github.com/MrStaticVoid/profile.git',
        ssh_key_source => 'puppet:///modules/private/nest/users/jlee/id_dsa',
        require        => flatten($require),
    }


    #
    # Admins are to use sudo
    #
    class { 'sudo': }

    sudo::conf { 'env':
        content => 'Defaults env_keep += "SSH_AUTH_SOCK SSH_CLIENT XAUTHORITY"',
    }

    sudo::conf { 'wheel':
        content => '%wheel ALL=(ALL) NOPASSWD: ALL',
    }


    #
    # root mail goes to the right place
    #
    postfix::alias { 'root':
        recipient => 'jlee@thestaticvoid.com',
    }
}
