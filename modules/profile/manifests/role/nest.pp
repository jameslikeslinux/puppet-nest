class profile::role::nest {
    class { 'sabnzbd': }

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
        createmask => '0644',
    }

    package_use { 'media-libs/chromaprint':
        use     => 'tools',
        version => '>=0.7',
    }

    portage::package { 'media-sound/picard':
        ensure  => installed,
        require => Package_use['media-libs/chromaprint'],
    }
}
