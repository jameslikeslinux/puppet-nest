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
}
