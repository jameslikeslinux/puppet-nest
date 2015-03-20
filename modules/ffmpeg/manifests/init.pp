class ffmpeg {
    portage::package { 'media-video/ffmpeg':
        ensure => installed,
        use    => 'threads',
    }
}
