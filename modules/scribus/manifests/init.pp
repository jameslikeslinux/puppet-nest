class scribus {
    package_use { 'dev-libs/libpcre':
        use => 'pcre16',
    }

    package_use { 'x11-libs/libxcb':
        use => 'xkb',
    }

    portage::package { 'app-office/scribus':
        ensure  => installed,
        require => [
            Package_use['dev-libs/libpcre'],
            Package_use['x11-libs/libxcb'],
        ],
    }
}
