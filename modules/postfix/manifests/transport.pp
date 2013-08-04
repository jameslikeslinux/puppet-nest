class postfix::transport (
    $map = {},
) {
    file { '/etc/postfix/transport':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('postfix/transport.erb'),
        require => Portage::Package['mail-mta/postfix'],
        notify  => Exec['postmap-transport'],
    }

    exec { 'postmap-transport':
        command     => '/usr/sbin/postmap /etc/postfix/transport',
        refreshonly => true,
        before      => Postfix::Conf['transport'],
    }

    postfix::conf { 'transport':
        source => 'puppet:///modules/postfix/transport.cf',
    } 
}
