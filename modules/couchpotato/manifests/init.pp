class couchpotato (
    $uid,
    $gid,
    $home,
) {
    group { 'couchpotato':
        gid => $gid,
    }

    users::user { 'couchpotato':
        uid      => $uid,
        gid      => 'couchpotato',
        fullname => 'CouchPotato User',
        shell    => '/sbin/nologin',
        profile  => 'https://github.com/RuudBurger/CouchPotatoServer.git',
        home     => $home,
        notify   => Openrc::Service['couchpotato'],
    }

    file { '/etc/init.d/couchpotato':
        mode    => '0755',
        owner   => 'root',
        group   => 'root',
        content => template('couchpotato/initd.erb'),
    }

    openrc::service { 'couchpotato':
        enable  => true,
        require => [
            Users::User['couchpotato'],
            File['/etc/init.d/couchpotato'],
        ],
    }
}
