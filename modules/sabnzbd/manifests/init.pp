class sabnzbd {
    portage::package { 'net-nntp/sabnzbd':
        ensure => installed,
    }

    openrc::service { 'sabnzbd':
        enable  => true,
        require => Portage::Package['net-nntp/sabnzbd'],
    }
}
