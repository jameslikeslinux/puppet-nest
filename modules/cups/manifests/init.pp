class cups (
    $system_group = 'wheel',
    $kde          = false,
    $avahi        = false,
) {
    portage::package { [
        'net-print/cups-filters',
        'net-print/cups',
    ]:
        use => $avahi ? {
            false   => undef,
            default => 'zeroconf',
        }
    }

    portage::package { 'net-print/foomatic-db':
        ensure => installed,
    }

    file { '/etc/cups/cups-files.conf':
        mode    => '0640',
        owner   => 'root',
        group   => 'lp',
        content => template('cups/cups-files.conf.erb'),
        require => Portage::Package['net-print/cups'],
        notify  => Openrc::Service['cupsd'],
    }

    openrc::service { 'cupsd':
        enable  => true,
        require => File['/etc/cups/cups-files.conf'],
    }

    openrc::service { 'cups-browsed':
        enable  => true,
        require => Portage::Package['net-print/cups-filters'],
    }

    if $kde {
        portage::package { 'kde-base/print-manager':
            ensure => installed,
        }
    }
}
