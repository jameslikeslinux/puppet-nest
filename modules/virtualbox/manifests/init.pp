class virtualbox (
    $autostart_users = [],
) {
    portage::package { 'app-emulation/virtualbox-bin':
        ensure  => installed,
        use     => 'rdesktop-vrdp',
        require => Class['kernel'],
    }

    file { '/etc/default/virtualbox':
        mode   => '0644',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/virtualbox/virtualbox.default',
    }

    file { '/etc/vbox/autostart.cfg':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('virtualbox/autostart.cfg.erb'),
        require => Portage::Package['app-emulation/virtualbox-bin'],
    }

    file { '/etc/vbox/autostart':
        ensure  => directory,
        mode    => '0775',
        owner   => 'root',
        group   => 'vboxusers',
        require => Portage::Package['app-emulation/virtualbox-bin'],
    }
}
