class firefox {
    portage::package { 'www-client/firefox':
        ensure  => installed,
        use     => ['gstreamer', 'libnotify', 'startup-notification'],
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
