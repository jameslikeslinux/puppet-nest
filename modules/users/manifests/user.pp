define users::user (
    $uid,
    $groups = [],
    $fullname,
    $shell,
    $zfs_dataset = undef,
    $profile = undef,
) {
    include users

    if $zfs_dataset {
        exec { "/sbin/zfs create -o mountpoint=/home/${name} ${zfs_dataset}":
            unless  => "/sbin/zfs list -H -o name | /bin/grep '^${zfs_dataset}$'",
            before  => File["/home/${name}"],
            require => Class['zfs'],
        }
    }

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
}
