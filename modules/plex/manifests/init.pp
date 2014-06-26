class plex {
    portage::package { 'media-tv/plex-media-server':
        ensure => installed,
    }

    openrc::service { 'plex-media-server':
        enable => true,
        require => Portage::Package['media-tv/plex-media-server'],
    }

    iptables::accept { 'plex':
        port     => 32400,
        protocol => tcp,
    }
}
