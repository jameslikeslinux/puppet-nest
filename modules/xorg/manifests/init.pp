class xorg (
    $video_cards = [],
    $keymap      = 'us',
    $xkboptions  = '',
) {
    $flavor = "funtoo/1.0/linux-gnu/flavor/desktop"
    exec { "eselect-profile-flavor":
        command => "/usr/bin/eselect profile set-flavor '${flavor}'",
        unless  => "/usr/bin/eselect profile show | /bin/grep '${flavor}'",
        notify  => Class['portage'],
    }

    class { 'makeconf::use::xinerama': }

    portage::makeconf { 'video_cards':
        content => join($video_cards, ' '),
    }

    portage::package { 'x11-base/xorg-x11':
        ensure => installed,
    }

    portage::package { 'x11-apps/xinit':
        ensure => installed,
        use    => '-minimal',
    }

    #
    # Setting keyboard layout with hotplugging:
    # https://wiki.archlinux.org/index.php/Xorg#Setting_keyboard_layout_with_hot-plugging
    #
    file { '/etc/X11/xorg.conf.d':
        ensure  => directory,
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        require => Portage::Package['x11-base/xorg-x11'],
    }

    file { '/etc/X11/xorg.conf.d/10-keyboard.conf':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('xorg/keyboard.erb'),
        require => File['/etc/X11/xorg.conf.d'],
    }

    #
    # Enable sync to vblank for nouveau
    # https://wiki.archlinux.org/index.php/Nouveau#Tear-free_compositing
    #
    if 'nouveau' in $video_cards {
        file { '/etc/X11/xorg.conf.d/20-nouveau.conf':
            mode    => '0644',
            owner   => 'root',
            group   => 'root',
            source  => 'puppet:///modules/xorg/nouveau.conf',
            require => File['/etc/X11/xorg.conf.d'],
        }
    }
}
