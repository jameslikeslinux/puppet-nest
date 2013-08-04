class postfix::relay (
    $relayhost,
    $username = undef,
    $password = undef,
    $tls      = false,
    $cacert   = undef,
) inherits postfix {
    Portage::Package['mail-mta/postfix'] {
        use +> 'sasl',
    }

    if $username and $password {
        file { '/etc/postfix/sasl_passwd':
            mode    => '0600',
            owner   => 'root',
            group   => 'root',
            content => template('postfix/sasl_passwd.erb'),
            require => Portage::Package['mail-mta/postfix'],
            notify  => Exec['postmap-sasl_passwd'],
        }

        exec { 'postmap-sasl_passwd':
            command     => '/usr/sbin/postmap /etc/postfix/sasl_passwd',
            refreshonly => true,
            before      => Postfix::Conf['relay'],
        }
    }

    if $cacert {
        file { '/etc/postfix/CAcert.pem':
            mode    => '0644',
            owner   => 'root',
            group   => 'root',
            source  => $cacert,
            require => Portage::Package['mail-mta/postfix'],
            before  => Postfix::Conf['relay'],
        }
    }

    postfix::conf { 'relay':
        content => template('postfix/relay.cf.erb'),
    } 
}
