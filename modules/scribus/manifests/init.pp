class scribus {
    portage::package { 'app-office/scribus':
        ensure  => installed,
        require => Class['kde'],
    }
}
