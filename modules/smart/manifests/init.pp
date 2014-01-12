class smart {
    portage::package { 'sys-apps/smartmontools':
        ensure => installed,
    }

    file { '/etc/smartd.conf':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/smart/smartd.conf',
        require => Portage::Package['sys-apps/smartmontools'],
        notify  => Openrc::Service['smartd'],
    }

    openrc::service { 'smartd':
        enable  => true,
        require => File['/etc/smartd.conf'],
    }
}
