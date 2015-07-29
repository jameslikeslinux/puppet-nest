class solaar {
    portage::package { 'app-misc/solaar':
        ensure => installed,
    }

    file { '/etc/X11/xinit/xinitrc.d/99-xmodmap':
        mode    => '0755',
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/solaar/99-xmodmap',
        require => Class['xorg'],
    }
}
