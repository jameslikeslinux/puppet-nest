define users::user (
    $uid,
    $groups = [],
    $fullname,
    $shell,
    $profile = undef,
    $ssh_key_source = undef,
) {
    include users

    user { $name:
        uid     => $uid,
        gid     => 'users',
        groups  => $groups,
        home    => "/home/${name}",
        comment => $fullname,
        shell   => $shell,
        require => Class['users'],
    }

    file { "/home/${name}":
        ensure  => directory,
        owner   => $name,
        group   => 'users',
        require => User[$name],
    }

    if $profile {
        users::profile { "/home/${name}":
            user    => $name,
            source  => $profile,
            require => File["/home/${name}"],
        }
    }

    if $ssh_key_source {
        $filename = regsubst($ssh_key_source, '^.*/([^/]+)$', '\1')

        file { "/home/${name}/.ssh":
            ensure => directory,
            mode   => '0644',
            owner  => $name,
            group  => 'users',
        }

        file { "/home/${name}/.ssh/${filename}":
            mode    => '0600',
            owner   => $name,
            group   => 'users',
            source  => $ssh_key_source,
            replace => false,
        }

        file { "/home/${name}/.ssh/${filename}.pub":
            mode    => '0644',
            owner   => $name,
            group   => 'users',
            source  => "${ssh_key_source}.pub",
            replace => false,
        }
    }
}
