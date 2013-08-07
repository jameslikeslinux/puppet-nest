class profile::base::users {
    #
    # Has a user.
    #
    class { 'zsh': }

    users::user { 'jlee':
        uid            => 1000,
        groups         => ['wheel'],
        fullname       => 'James Lee',
        shell          => '/bin/zsh',
        profile        => 'git://github.com/MrStaticVoid/profile.git',
        ssh_key_source => 'puppet:///modules/private/profile/base/users/jlee/id_dsa',
        require        => Class['zsh'],
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
}
