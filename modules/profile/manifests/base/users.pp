class profile::base::users {
    #
    # Has a user.
    #
    class { 'zsh': }

    users::user { 'jlee':
        uid         => 1000,
        groups      => ['wheel'],
        fullname    => 'James Lee',
        shell       => '/bin/zsh',
        zfs_dataset => 'rpool/home/jlee',
        profile     => 'git://github.com/MrStaticVoid/profile.git',
        require     => Class['zsh'],
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
