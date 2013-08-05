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
        xkboptions  => 'ctrl:nocaps',
    }


    #
    # Has beautiful fonts.
    #
    class { 'fonts': }


    #
    # Has KDE.
    #
    class { 'kde': }


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
    profile::role { 'cups': }
}
