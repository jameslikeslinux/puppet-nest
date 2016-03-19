class skype {
    package_use { 'dev-qt/qtwebkit':
        use => '-exceptions',
    }

    portage::package { 'net-im/skype':
        use     => ['-pulseaudio', 'apulse'],
        require => Package_use['dev-qt/qtwebkit'],
    }
}
