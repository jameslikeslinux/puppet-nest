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

    file { '/etc/tomcat-7-subsonic/catalina.properties':
        mode    => '0640',
        owner   => 'subsonic',
        group   => 'subsonic',
        source  => 'puppet:///modules/subsonic/catalina.properties',
        require => Tomcat::Instance['subsonic'],
        notify  => Openrc::Service["tomcat-7-${name}"],
    }

    file { '/etc/tomcat-7-subsonic/context.xml':
        mode    => '0640',
        owner   => 'subsonic',
        group   => 'subsonic',
        source  => 'puppet:///modules/subsonic/context.xml',
        require => Tomcat::Instance['subsonic'],
        notify  => Openrc::Service["tomcat-7-${name}"],
    }

    file { '/var/lib/tomcat-7-subsonic/webapps/subsonic.war':
        mode    => '0644',
        owner   => 'subsonic',
        group   => 'subsonic',
        source  => 'puppet:///modules/subsonic/subsonic.war',
        require => Tomcat::Instance['subsonic'],
        notify  => Openrc::Service["tomcat-7-${name}"],
    }

    openrc::service { "tomcat-7-${name}":
        enable  => $enable,
        require => [
            File['/etc/tomcat-7-subsonic/catalina.properties'],
            File['/etc/tomcat-7-subsonic/context.xml'],
            File['/var/lib/tomcat-7-subsonic/webapps/subsonic.war'],
        ],
    }
}
