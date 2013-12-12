class openafs (
    $thiscell,
) {
    portage::package { 'net-fs/openafs':
        use     => 'kerberos',
        require => [
            Class['kernel'],
            Class['kerberos'],
        ],
    }

    file { '/etc/openafs/ThisCell':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => "${thiscell}\n",
        require => Portage::Package['net-fs/openafs'],
        notify  => Openrc::Service['openafs-client'],
    }

    openrc::service { 'openafs-client':
        enable  => true,
        require => File['/etc/openafs/ThisCell'],
    }
}
