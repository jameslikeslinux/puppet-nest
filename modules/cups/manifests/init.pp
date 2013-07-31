class cups (
    $kde = false,
) {
    portage::package { 'net-print/cups':
        ensure => installed,
    }

    openrc::service { 'cupsd':
        enable  => true,
        require => Portage::Package['net-print/cups'],
    }

    if $kde {
        portage::package { 'kde-base/print-manager':
            ensure => installed,
        }
    }
}
