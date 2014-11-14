class kerberos (
    $default_realm,
    $mappings = undef,
) {
    portage::package { 'app-crypt/heimdal':
        ensure => absent,
        before => Portage::Package['app-crypt/mit-krb5'],
    }

    portage::package { 'app-crypt/mit-krb5':
        ensure => installed,
    }

    portage::package { 'virtual/krb5':
        ensure  => installed,
        require => Portage::Package['app-crypt/mit-krb5'],
    }

    file { '/etc/krb5.conf':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('kerberos/krb5.conf.erb'),
        require => Portage::Package['virtual/krb5'],
    }
}
