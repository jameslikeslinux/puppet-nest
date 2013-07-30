class polkit {
    portage::package { 'sys-auth/polkit':
        ensure => 'installed',
    }

    file { '/etc/polkit-1/rules.d/40-admin.rules':
        mode    => 644,
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/polkit/admin.rules',
        require => Portage::Package['sys-auth/polkit'],
    }
}
