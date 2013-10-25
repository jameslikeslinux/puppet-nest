class texlive {
    package_use { 'app-text/texlive-core':
        use    => 'xetex',
    }

    portage::package { 'app-text/texlive':
        use     => ['luatex', 'xetex'],
        ensure  => installed,
        require => Package_use['app-text/texlive-core'],
    }
}
