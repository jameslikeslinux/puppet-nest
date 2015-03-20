class mplayer {
    portage::package { 'media-video/mplayer':
        ensure => installed,
    }

    file { '/etc/mplayer/mplayer.conf':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/mplayer/mplayer.conf',
        require => Portage::Package['media-video/mplayer'],
    }
}
