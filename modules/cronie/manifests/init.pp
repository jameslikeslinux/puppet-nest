class cronie {
    portage::package { 'sys-process/cronie':
        use    => 'inotify',
        ensure => installed,
    }

    openrc::service { 'cronie':
        enable  => true,
        require => Portage::Package['sys-process/cronie'],
    }
}
