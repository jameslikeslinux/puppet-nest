class sabnzbd (
    $user  = 'sabnzbd',
    $group = 'sabnzbd',
) {
    portage::package { 'net-nntp/sabnzbd':
        ensure => installed,
    }

    file { [
        '/etc/sabnzbd',
        '/var/lib/sabnzbd',
        '/var/log/sabnzbd',
    ]:
        owner   => $user,
        group   => $group,
        recurse => true,
        links   => follow,
        require => Portage::Package['net-nntp/sabnzbd'],
    }

    file { '/etc/conf.d/sabnzbd':
        owner   => root,
        group   => root,
        content => template('sabnzbd/sabnzbd.confd.erb'),
        require => Portage::Package['net-nntp/sabnzbd'],
    }

    openrc::service { 'sabnzbd':
        enable  => true,
        require => Portage::Package['net-nntp/sabnzbd'],
    }
}
