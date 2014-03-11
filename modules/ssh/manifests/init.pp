class ssh {
    $kerberos = defined(Class['kerberos'])

    portage::package { 'net-misc/openssh':
        use => $kerberos ? {
            true    => 'kerberos',
            default => undef,
        },

        require => $kerberos ? {
            true    => Class['kerberos'],
            default => undef,
        }
    }

    include ssh::client
}
