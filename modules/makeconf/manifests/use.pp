define makeconf::use (
    $networkmanager = false,
    $pulseaudio     = false,
    $xinerama       = false,
    $zsh_completion = false,
) {
    $networkmanager_use = $networkmanager ? {
        true    => 'networkmanager ',
        default => '',
    }

    $pulseaudio_use = $pulseaudio ? {
        true    => 'pulseaudio ',
        default => '',
    }

    $xinerama_use = $xinerama ? {
        true    => 'xinerama ',
        default => '',
    }

    $zsh_completion_use = $zsh_completion ? {
        true    => 'zsh-completion ',
        default => '',
    }

    $use = [$networkmanager_use, $pulseaudio_use, $xinerama_use, $zsh_completion_use]

    portage::makeconf { 'use':
        content => join($use, ''),
    }
}
