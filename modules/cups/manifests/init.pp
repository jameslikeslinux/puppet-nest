class cups {
    portage::package { 'net-print/cups':
        ensure => 'installed',
    }

    openrc::service { 'cupsd':
        enable  => true,
        require => Portage::Package['net-print/cups'],
    }

    if defined(Class['kde']) {
        portage::package { 'kde-base/print-manager':
            ensure => 'installed',
        }
    }
}
