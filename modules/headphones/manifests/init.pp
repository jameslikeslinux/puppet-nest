class headphones (
    $uid,
    $gid,
    $home,
) {
    group { 'headphones':
        gid => $gid,
    }

    users::user { 'headphones':
        uid      => $uid,
        gid      => 'headphones',
        fullname => 'Headphones User',
        shell    => '/sbin/nologin',
        profile  => 'https://github.com/rembo10/headphones.git',
        home     => $home,
        notify   => Openrc::Service['headphones'],
    }

    file { '/etc/init.d/headphones':
        mode    => '0755',
        owner   => 'root',
        group   => 'root',
        content => template('headphones/initd.erb'),
    }

    openrc::service { 'headphones':
        enable  => true,
        require => [
            Users::User['headphones'],
            File['/etc/init.d/headphones'],
        ],
    }
}
