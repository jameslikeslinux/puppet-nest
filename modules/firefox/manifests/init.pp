class firefox {
    portage::package { 'media-plugins/gst-plugins-meta':
        ensure => 'installed',
        use    => 'ffmpeg',
    }

    portage::package { 'www-client/firefox':
        ensure  => 'installed',
        use     => ['gstreamer', 'libnotify', 'startup-notification'],
        require => Portage::Package['media-plugins/gst-plugins-meta'],
    }

    portage::package { 'www-plugins/adobe-flash':
        ensure => 'installed',
    }
}
