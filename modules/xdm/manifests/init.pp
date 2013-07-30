class xdm (
    $displaymanager = 'xdm',
) {
    file { '/etc/conf.d/xdm':
        mode    => 644,
        owner   => root,
        group   => root,
        content => template('xdm/xdm.erb'),
    }

    openrc::service { 'xdm':
        enable  => true,
    }

    Class['xorg'] -> Class['xdm']
}
