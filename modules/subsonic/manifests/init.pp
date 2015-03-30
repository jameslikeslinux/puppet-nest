class subsonic (
    $enable = true,
) {
    group { 'subsonic':
        ensure => present,
    }

    user { 'subsonic':
        gid     => 'subsonic',
        home    => '/var/subsonic',
        comment => 'Subsonic Music Streamer',
        shell   => '/sbin/nologin',
        require => Group['subsonic'],
    }

    tomcat::instance { 'subsonic':
        user    => 'subsonic',
        group   => 'subsonic',
        require => [
            User['subsonic'],
            Group['subsonic'],
        ],        
    }

    file { '/var/lib/tomcat-8-subsonic/webapps/subsonic.war':
        mode    => '0644',
        owner   => 'subsonic',
        group   => 'subsonic',
        source  => 'puppet:///modules/subsonic/subsonic.war',
        require => Tomcat::Instance['subsonic'],
        notify  => Openrc::Service["tomcat-8-${name}"],
    }

    openrc::service { "tomcat-8-${name}":
        enable  => $enable,
        require => File['/var/lib/tomcat-8-subsonic/webapps/subsonic.war'],
    }
}
