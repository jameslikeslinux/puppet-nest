class polkit (
    $admin_group = 'wheel',
) {
    portage::package { 'sys-auth/polkit':
        ensure => installed,
    }

    file { '/etc/polkit-1/rules.d/40-admin.rules':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('polkit/admin.rules.erb'),
        require => Portage::Package['sys-auth/polkit'],
    }
}
