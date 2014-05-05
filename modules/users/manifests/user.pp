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
        users::sshkey { $name:
            ssh_key_source => $ssh_key_source,
            home           => $home,
            gid            => $gid,
        }
    }
}
