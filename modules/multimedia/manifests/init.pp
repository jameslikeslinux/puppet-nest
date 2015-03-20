class multimedia {
    portage::package { [
        'media-libs/flac',
        'media-sound/lame',
        'media-sound/mpg123',
    ]:
        ensure => installed,
    }

    portage::package { 'media-plugins/gst-plugins-meta':
        ensure  => installed,
        use     => 'ffmpeg',
        require => Class['ffmpeg'],
    }
}
