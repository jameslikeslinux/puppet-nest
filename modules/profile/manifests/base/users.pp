class profile::base::users {
    include private::profile::base::users

    #
    # Has a user.
    #
    class { 'zsh': }


    $virtalbox = virtualbox in $profile::base::roles
    $terminal_client = terminal_client in $profile::base::roles

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
        profile        => 'git://github.com/MrStaticVoid/profile.git',
        ssh_key_source => 'puppet:///modules/private/profile/base/users/jlee/id_dsa',
        require        => flatten($require),
    }


    #
    # That user's identity is the same as the root's identity,
    # for better or worse.
    #
    users::user { 'root':
        uid      => 0,
        gid      => 0,
        fullname => 'root',
        shell    => '/bin/zsh',
        home     => '/root',
        profile  => 'git://github.com/MrStaticVoid/profile.git',
        password => $::private::profile::base::users::root_pwhash,
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
