class firefox {
    portage::package { 'media-video/ffmpeg':
        use    => 'threads',
        ensure => installed,
    }

    portage::package { 'media-plugins/gst-plugins-meta':
        ensure  => installed,
        use     => 'ffmpeg',
        require => Portage::Package['media-video/ffmpeg'],
    }

    portage::package { 'www-client/firefox':
        ensure  => installed,
        use     => ['gstreamer', 'libnotify', 'startup-notification'],
        require => Portage::Package['media-plugins/gst-plugins-meta'],
    }

    portage::package { [
        'www-plugins/adobe-flash',
        'media-libs/hal-flash',
    ]:
        ensure => installed,
    }
}
