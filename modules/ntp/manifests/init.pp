class ntp {
    portage::package { 'net-misc/ntp':
        ensure => 'installed',
    }

    openrc::service { 'ntpd':
        enable  => true,
        require => Portage::Package['net-misc/ntp'],
    }
}
