class pam (
    $ssh     = false,
    $krb5    = false,
    $lastlog = false,
) {
    $use = [
        $ssh ? {
            false   => [],
            default => 'pam_ssh',
        },

        $krb5 ? {
            false   => [],
            default => 'pam_krb5',
        },
    ]

    if $krb5 {
        package_mask { 'sys-auth/pam_krb5':
            version => '>4',
            before  => Portage::Package['sys-auth/pambase'],
        }
    }

    portage::package { 'sys-auth/pambase':
        ensure => installed,
        use    => $use,
    }

    file { '/etc/pam.d/system-auth':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('pam/system-auth.erb'),
        require => Portage::Package['sys-auth/pambase'],
    }

    file { '/etc/pam.d/system-login':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('pam/system-login.erb'),
        require => Portage::Package['sys-auth/pambase'],
    }
}
