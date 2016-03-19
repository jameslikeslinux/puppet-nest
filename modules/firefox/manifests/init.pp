class firefox {
    package_use { 'x11-libs/cairo':
        use    => 'xcb',
        ensure => absent,
    }

    portage::package { 'www-client/firefox':
        ensure  => absent,
        use     => ['gstreamer', 'libnotify', 'startup-notification'],
        require => Package_use['x11-libs/cairo'],
    }

    portage::package { 'www-client/firefox-bin':
        ensure => installed,
    }

    portage::package { [
        'www-plugins/adobe-flash',
        'media-libs/hal-flash',
    ]:
        ensure => installed,
    }

    exec { 'patch-flash-fullscreen-focus':
        command => '/bin/sed -i "s/_NET_ACTIVE_WINDOW/_XET_ACTIVE_WINDOW/g" /usr/lib64/nsbrowser/plugins/libflashplayer.so',
        onlyif  => '/bin/grep "_NET_ACTIVE_WINDOW" /usr/lib64/nsbrowser/plugins/libflashplayer.so',
        require => Portage::Package['www-plugins/adobe-flash'],
    }
}
