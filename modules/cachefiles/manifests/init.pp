class cachefiles {
    portage::package { 'sys-fs/cachefilesd':
        ensure => installed,
    }

    openrc::service { 'cachefilesd':
        enable  => true,
        require => Portage::Package['sys-fs/cachefilesd'],
    }
}
