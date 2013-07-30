class kerberos {
    portage::package { 'app-crypt/heimdal':
        ensure => 'installed',
    }

    portage::package { 'virtual/krb5':
        ensure  => 'installed',
        require => Portage::Package['app-crypt/heimdal'],
    }
}
