class kerberos (
    $default_realm,
) {
    portage::package { 'app-crypt/heimdal':
        ensure => installed,
    }

    portage::package { 'virtual/krb5':
        ensure  => installed,
        require => Portage::Package['app-crypt/heimdal'],
    }

    file { '/etc/krb5.conf':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('kerberos/krb5.conf.erb'),
        require => Portage::Package['virtual/krb5'],
    }
}
