class postfix {
    portage::package { [
        'mail-mta/postfix',
        'mail-client/mailx',
    ]:
        ensure => installed,
    }

    concat { 'postfix-main.cf':
        path    => '/etc/postfix/main.cf',
        warn    => true,
        require => Portage::Package['mail-mta/postfix'],
        notify  => Openrc::Service['postfix'],
    }

    postfix::conf { 'main':
        source => 'puppet:///modules/postfix/main.cf',
        order  => '00',
    }

    file { '/etc/postfix/master.cf':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/postfix/master.cf',
        require => Portage::Package['mail-mta/postfix'],
        notify  => Openrc::Service['postfix'],
    }

    openrc::service { 'postfix':
        enable  => true,
        require => Concat['postfix-main.cf'],
    }
}
