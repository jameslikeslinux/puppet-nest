class nzbdrone (
    $uid,
    $gid,
    $home,
) {
    group { 'nzbdrone':
        gid => $gid,
    }

    users::user { 'nzbdrone':
        uid      => $uid,
        gid      => 'nzbdrone',
        fullname => 'NzbDrone User',
        shell    => '/sbin/nologin',
        home     => $home,
    }

    exec { 'fetch-nzbdrone':
        user    => 'nzbdrone',
        command => "/usr/bin/wget -q http://update.sonarr.tv/v2/master/mono/NzbDrone.master.tar.gz -O ${home}/NzbDrone.master.tar.gz",
        creates => "${home}/NzbDrone.master.tar.gz",
        require => Users::User['nzbdrone'],
    }

    exec { 'extract-nzbdrone':
        user        => 'nzbdrone',
        command     => "/bin/tar -C ${home} -xf ${home}/NzbDrone.master.tar.gz --strip 1",
        refreshonly => true,
        subscribe   => Exec['fetch-nzbdrone'],
        notify      => Openrc::Service['nzbdrone'],
    }

    file { '/etc/init.d/nzbdrone':
        mode    => '0755',
        owner   => 'root',
        group   => 'root',
        content => template('nzbdrone/initd.erb'),
    }

    portage::package { [
        'dev-lang/mono',
        'media-libs/libmediainfo',
    ]:
        ensure => 'installed',
        before => Openrc::Service['nzbdrone'],
    }

    openrc::service { 'nzbdrone':
        enable  => true,
        require => [
            Exec['extract-nzbdrone'],
            File['/etc/init.d/nzbdrone'],
        ],
    }
}
