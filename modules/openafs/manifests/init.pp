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

    file { '/etc/openafs/cacheinfo':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => "/afs:/var/cache/afs:200000\n",
        require => Portage::Package['net-fs/openafs'],
        notify  => Openrc::Service['openafs-client'],
    }

    openrc::service { 'openafs-client':
        enable  => true,
        require => [
            File['/etc/openafs/ThisCell'],
            File['/etc/openafs/cacheinfo'],
        ],
    }
}
