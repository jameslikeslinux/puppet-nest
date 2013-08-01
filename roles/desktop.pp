class role::desktop (
    $video_cards = [],
) {
    #
    # Has an X server with good keyboard settings.
    #
    class { 'xorg':
        video_cards => $video_cards,
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
    class { 'cups':
        kde => true,
    }
}
