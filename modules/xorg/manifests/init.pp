class xorg (
    $video_cards   = [],
    $keymap        = 'us',
    $xkbvariant    = undef,
    $xkboptions    = [],
    $deviceoptions = {},
) {
    $flavor = "funtoo/1.0/linux-gnu/flavor/desktop"
    exec { "eselect-profile-flavor":
        command => "/usr/bin/eselect profile set-flavor '${flavor}'",
        unless  => "/usr/bin/eselect profile show | /bin/grep '${flavor}'",
        notify  => Class['portage'],
    }

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
    $nouveau = 'nouveau' in $video_cards
    file { '/etc/X11/xorg.conf.d/20-nouveau.conf':
        ensure  => $nouveau ? {
            true    => present,
            default => absent,
        },
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/xorg/nouveau.conf',
        require => File['/etc/X11/xorg.conf.d'],
    }

    #
    # Emulate middle mouse button
    #
    file { '/etc/X11/xorg.conf.d/10-pointer.conf':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/xorg/pointer.conf',
        require => File['/etc/X11/xorg.conf.d'],
    }

    #
    # Enable trackpoint scrolling
    #
    file { '/etc/X11/xorg.conf.d/20-trackpoint.conf':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/xorg/trackpoint.conf',
        require => File['/etc/X11/xorg.conf.d'],
    }


    #
    # R600 cards need firmware in initramfs
    #
    if 'radeon' in $video_cards {
        portage::package { 'x11-drivers/radeon-ucode':
            ensure => installed,
            before => Class['kernel::initrd'],
        }

        package_use { 'media-libs/mesa':
            use => 'gbm',
        }
    }

    if 'fglrx' in $video_cards {
        kernel::modules::blacklist { 'radeon': }
    }


    #
    # Proprietary NVIDIA driver stuff
    #
    $nvidia = 'nvidia' in $video_cards

    if $nvidia {
        kernel::modules::blacklist { 'nouveau': }

        package_use { 'x11-drivers/nvidia-drivers':
            use => 'gtk2',
        }
    }

    file { '/etc/X11/xorg.conf.d/20-nvidia.conf':
        ensure  => $nvidia ? {
            true    => present,
            default => absent,
        },
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('xorg/nvidia.erb'),
        require => File['/etc/X11/xorg.conf.d'],
    }

    portage::package { 'x11-apps/mesa-progs':
        ensure => installed,
    }
}
