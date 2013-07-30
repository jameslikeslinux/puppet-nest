class users {
    group { 'users':
        gid => '1000',
    }

    file { '/etc/default/useradd':
        mode    => 600,
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/users/useradd',
        require => Group['users'],
    }
}
