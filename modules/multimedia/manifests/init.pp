class multimedia {
    portage::package { [
        'media-libs/flac',
        'media-sound/lame',
        'media-sound/mpg123',
        'media-video/mplayer',
    ]:
        ensure => installed,
    }

    portage::package { 'media-video/ffmpeg':
        use    => 'threads',
        ensure => installed,
    }

    portage::package { 'media-plugins/gst-plugins-meta':
        ensure  => installed,
        use     => 'ffmpeg',
        require => Portage::Package['media-video/ffmpeg'],
    }
}
