class profile::base::users {
    #
    # Has a user.
    #
    class { 'zsh': }


    $virtalbox = virtualbox in $profile::base::roles
    $terminal_client = terminal_client in $profile::base::roles

    $groups = [
        $virtualbox ? {
            true    => 'virtualbox',
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
    users::profile { '/root':
        user   => 'root',
        source => 'git://github.com/MrStaticVoid/profile.git',
    }


    #
    # Admins are to use sudo or polkit
    #
    class { 'sudo': }

    sudo::conf { 'env':
        content => 'Defaults env_keep += "SSH_AUTH_SOCK XAUTHORITY"',
    }

    sudo::conf { 'wheel':
        content => '%wheel ALL=(ALL) NOPASSWD: ALL',
    }

    class { 'polkit':
        admin_group => 'wheel',
    }


    #
    # ...not the root account.
    #
    exec { '/usr/bin/passwd --lock root':
        unless => '/usr/bin/passwd --status root | /bin/grep " L "',
    }


    #
    # root mail goes to the right place
    #
    postfix::alias { 'root':
        recipient => 'jlee@thestaticvoid.com',
    }
}
