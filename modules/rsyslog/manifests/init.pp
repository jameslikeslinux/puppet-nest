class rsyslog {
    # Fix stupid Portage
    include misc::boehmgc

    portage::package { [
        'app-admin/rsyslog',
        'app-admin/logrotate',
    ]:
        ensure  => installed,
        require => Class['misc::boehmgc'],
    }

    file { '/etc/conf.d/rsyslog':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/rsyslog/rsyslog.confd',
        require => Portage::Package['app-admin/rsyslog'],
        notify  => Openrc::Service['rsyslog'],
    }

    openrc::service { 'rsyslog':
        enable  => true,
        require => File['/etc/conf.d/rsyslog'],
    }
}
