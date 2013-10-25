class profile::role::desktop {
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
        video_cards => $profile::base::video_cards,
        keymap      => 'dvorak',
        xkboptions  => ['ctrl:nocaps'],
    }


    #
    # Has beautiful fonts.
    #
    class { 'fonts':
        lcd => $profile::base::lcd,
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
        keymap      => 'dvorak',
        xkboptions  => ['ctrl:nocaps'],
        dpi         => $profile::base::dpi,
    }


    #
    # Has sound support.
    #
    class { 'sound': }


    #
    # Has things like ffmpeg and mplayer
    #
    class { 'multimedia': }


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
        use => '-webdav',
    }

    class { 'texlive': }


    #
    # Has Pidgin
    #
    class { 'pidgin': }


    portage::package { 'media-gfx/imagemagick':
        ensure => installed,
    }

    portage::package { 'www-client/google-chrome':
        ensure    => installed,
    }
}
