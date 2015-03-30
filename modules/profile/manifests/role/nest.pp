class profile::role::nest {
    class { 'sabnzbd': }

    class { 'couchpotato':
        uid  => 5050,
        gid  => 5050,
        home => '/app/couchpotato',
    }

#    class { 'headphones':
#        uid  => 8181,
#        gid  => 8181,
#        home => '/app/headphones',
#    }

    class { 'nzbdrone':
        uid  => 8989,
        gid  => 8989,
        home => '/app/nzbdrone',
    }

    class { 'transmission':
        port  => 51413,
    }

    class { 'plex': }

    class { 'crashplan': }

    class { 'nfs::server': }

    class { 'samba::server':
        workgroup => 'NEST',
    }

    samba::share { 'nest':
        path       => '/nest',
        writable   => true,
        createmask => '0664',
    }

    package_use { 'media-libs/chromaprint':
        use     => 'tools',
        version => '>=0.7',
    }

    portage::package { 'media-sound/picard':
        ensure  => installed,
        require => Package_use['media-libs/chromaprint'],
    }

    portage::package { 'media-sound/beets':
        ensure => installed,
        use    => ['convert', 'fetchart', 'replaygain'],
    }
}
