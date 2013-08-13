class rsyslog {
    portage::package { [
        'app-admin/rsyslog',
        'app-admin/logrotate',
    ]:
        ensure => installed,
    }

    openrc::service { 'rsyslog':
        enable  => true,
        require => Portage::Package['app-admin/rsyslog'],
    }
}
