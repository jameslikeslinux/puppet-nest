class inkscape {
    package_use { 'app-text/poppler':
        use => 'cairo',
    }

    portage::package { 'media-gfx/inkscape':
        ensure  => installed,
        use     => 'lcms',
        require => Package_use['app-text/poppler'],
    }
}
