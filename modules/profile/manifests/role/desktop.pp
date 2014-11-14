class profile::role::desktop {
    $keymap = $profile::base::keymap ? {
        /dvorak/ => 'us',
        default  => $profile::base::keymap,
    }

    $variant = $profile::base::keymap ? {
        /dvorak/ => $profile::base::keymap,
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
        video_cards   => $profile::base::video_cards,
        keymap        => $keymap,
        xkbvariant    => $variant,
        xkboptions    => ['ctrl:nocaps', 'terminate:ctrl_alt_bksp'],
        deviceoptions => $profile::base::video_options,
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
        keymap      => $keymap,
        xkbvariant  => $variant,
        xkboptions  => ['ctrl:nocaps', 'terminate:ctrl_alt_bksp'],
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
        use    => '-webdav',
        ensure => absent,
        before => Portage::Package['app-office/openoffice-bin'],
    }

    portage::package { 'app-office/openoffice-bin':
        ensure => installed,
    }

    class { 'texlive': }


    #
    # Has Pidgin
    #
    class { 'pidgin': }


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
