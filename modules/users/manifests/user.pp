define users::user (
    $uid,
    $gid = 'users',
    $groups = [],
    $fullname,
    $shell,
    $profile = undef,
    $ssh_key_source = undef,
    $home = "/home/${name}",
) {
    include users

    user { $name:
        uid     => $uid,
        gid     => $gid,
        groups  => $groups,
        home    => $home,
        comment => $fullname,
        shell   => $shell,
        require => Class['users'],
    }

    file { $home:
        ensure  => directory,
        owner   => $name,
        group   => $gid,
        require => User[$name],
    }

    if $profile {
        users::profile { $home:
            user    => $name,
            source  => $profile,
            require => File[$home],
        }
    }

    if $ssh_key_source {
        $filename = regsubst($ssh_key_source, '^.*/([^/]+)$', '\1')

        file { "${home}/.ssh":
            ensure => directory,
            mode   => '0644',
            owner  => $name,
            group  => $gid,
        }

        file { "${home}/.ssh/${filename}":
            mode    => '0600',
            owner   => $name,
            group   => $gid,
            source  => $ssh_key_source,
        }

        file { "${home}/.ssh/${filename}.pub":
            mode    => '0644',
            owner   => $name,
            group   => $gid,
            source  => "${ssh_key_source}.pub",
        }
    }
}
