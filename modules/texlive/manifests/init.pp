class texlive {
    package_use { 'media-libs/harfbuzz':
        use => 'graphite',
    }

    package_use { 'app-text/texlive-core':
        use => 'xetex',
    }

    portage::package { 'app-text/texlive':
        use     => ['luatex', 'xetex'],
        ensure  => installed,
        require => [
          Package_use['app-text/texlive-core'],
          Package_use['media-libs/harfbuzz'],
        ],
    }

    portage::package { 'dev-texlive/texlive-fontsextra':
        ensure  => installed,
        require => Portage::Package['app-text/texlive'],
    }
}
