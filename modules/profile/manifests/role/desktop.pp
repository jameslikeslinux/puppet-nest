class profile::role::desktop {
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
    # Has Mozilla apps
    #
    class { ['firefox', 'thunderbird']: }


    #
    # and printing support.
    #
    class { 'cups':
        kde => true,
    }


    #
    # Plays video
    #
    portage::package { 'media-video/mplayer':
        ensure => installed,
    }
}
