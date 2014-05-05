define users::sshkey (
    $ssh_key_source,
    $home,
    $gid,
) {
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
