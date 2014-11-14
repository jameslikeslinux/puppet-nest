define users::user (
    $uid,
    $gid = 'users',
    $groups = [],
    $fullname,
    $shell,
    $profile = undef,
    $profile_update = true,
    $ssh_key_source = undef,
    $password = undef,
    $home = "/home/${name}",
) {
    include users

    user { $name:
        uid      => $uid,
        gid      => $gid,
        groups   => $groups,
        home     => $home,
        comment  => $fullname,
        shell    => $shell,
        password => $password,
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
            update  => $profile_update,
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
