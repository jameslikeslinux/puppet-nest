class nest::role::desktop {
    $keymap = $nest::keymap ? {
        /dvorak/ => 'us',
        default  => $nest::keymap,
    }

    $variant = $nest::keymap ? {
        /dvorak/ => $nest::keymap,
        default  => undef,
    }

    class { 'polkit':
        admin_group => 'wheel',
    }


    #
    # Uses NetworkManager for networking
    #
    class { 'networkmanager':
        kde         => true,
        openconnect => true,
    }


    #
    # Has an X server with good keyboard settings.
    #
    class { 'xorg':
        video_cards   => $nest::video_cards,
        keymap        => $keymap,
        xkbvariant    => $variant,
        xkboptions    => ['ctrl:nocaps', 'terminate:ctrl_alt_bksp'],
        deviceoptions => $nest::video_options,
    }


    #
    # Has beautiful fonts.
    #
    class { 'fonts':
        lcd => $nest::lcd,
    }


    #
    # Has KDE.
    #
    class { 'kde': }


    #
    # Workaround bug in Logitech wireless keyboard layout setting:
    # https://wiki.archlinux.org/index.php/Logitech_Unifying_Receiver#Keyboard_layout_via_xorg.confthereceiver
    #
    class { 'kde::kdm':
        keymap      => $keymap,
        xkbvariant  => $variant,
        xkboptions  => ['ctrl:nocaps', 'terminate:ctrl_alt_bksp'],
        dpi         => $nest::dpi,
        synergy     => synergy_server in $nest::roles,
    }


    #
    # Has sound support.
    #
    class { 'sound': }


    #
    # Has things like ffmpeg and mplayer
    #
    class { 'multimedia': }
    class { 'ffmpeg': }
    class { 'mplayer': }


    #
    # Has Mozilla apps
    #
    class { ['firefox', 'thunderbird']:
        require => Class['multimedia'],
    }


    #
    # and printing support.
    #
    class { 'cups':
        kde => true,
    }


    #
    # Has LibreOffice and TexLive
    #
    portage::package { 'app-office/libreoffice':
        # use webdav is default; leads to compilation error
        #use    => '-webdav',
        ensure  => installed,
        #ensure => absent,
        #before => Portage::Package['app-office/openoffice-bin'],
    }

    portage::package { 'app-office/openoffice-bin':
        ensure => absent,
        before => Portage::Package['app-office/libreoffice'],
    }

#    portage::package { 'app-bin/libreoffice':
#        ensure => absent,
#        before => Portage::Package['app-office/libreoffice'],
#    }


    class { 'texlive': }


    #
    # Has Pidgin
    #
    class { 'pidgin': }


    #
    # Has a boot splash, maybe...
    #
    portage::package { 'sys-boot/plymouth':
        ensure => installed,
        before => Class['kernel::initrd'],
    }


    #
    # Miscellaneous packages
    #
    portage::package { [
        'media-gfx/argyllcms',
        'media-gfx/imagemagick',
        'www-client/google-chrome',
    ]:
        ensure => installed,
    }

    portage::package { 'net-misc/electrum':
        ensure => absent,
    }

    portage::package { 'media-sound/clementine':
        ensure => installed,
        use    => 'lastfm',
    }
}
