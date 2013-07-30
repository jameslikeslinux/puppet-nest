class desktop_role (
    $video_cards = [],
) inherits base_role {
    class { 'networkmanager': }

    class { 'sound': }

    class { 'polkit': }

    class { 'xorg':
        video_cards => $video_cards,
        keymap      => 'dvorak',
        xkboptions  => 'ctrl:nocaps',
    }

    class { 'kde': }

    class { 'fonts': }

    class { 'firefox': }

    class { 'thunderbird': }

    class { 'cups': }

    # XXX: or should I set 'SystemGroup wheel' in CUPS?
    Users::User['jlee'] {
        groups +> 'lpadmin',
    }
}
