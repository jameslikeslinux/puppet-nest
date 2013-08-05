class cups (
    $system_group = 'wheel',
    $kde          = false,
) {
    portage::package { [
        'net-print/cups-filters',
        'net-print/cups',
        'net-print/foomatic-db',
    ]:
        ensure => installed,
    }

    file { '/etc/cups/cupsd.conf':
        mode    => '0640',
        owner   => 'root',
        group   => 'lp',
        source  => 'puppet:///modules/cups/cupsd.conf',
        require => Portage::Package['net-print/cups'],
        notify  => Openrc::Service['cupsd'],
    }

    file { '/etc/cups/cups-files.conf':
        mode    => '0640',
        owner   => 'root',
        group   => 'lp',
        content => template('cups/cups-files.conf.erb'),
        require => Portage::Package['net-print/cups'],
        notify  => Openrc::Service['cupsd'],
    }

    file { '/etc/cups/cups-browsed.conf':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/cups/cups-browsed.conf',
        require => Portage::Package['net-print/cups-filters'],
        notify  => Openrc::Service['cups-browsed'],
    }

    openrc::service { 'cupsd':
        enable  => true,
        require => File['/etc/cups/cups-files.conf'],
    }

    openrc::service { 'cups-browsed':
        enable  => true,
        require => File['/etc/cups/cups-browsed.conf'],
    }

    if $kde {
        portage::package { 'kde-base/print-manager':
            ensure => installed,
        }
    }
}
