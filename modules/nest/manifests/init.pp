class nest (
    $arch               = x86,
    $boot_disk          = undef,
    $boot_options       = [],
    $default_sound_card = undef,
    $distcc             = false,
    $dpi                = undef,
    $keymap             = 'dvorak',
    $lcd                = true,
    $package_server     = undef,
    $remote_backup      = false,
    $resolution         = undef,
    $serial_console     = undef,
    $timezone           = 'America/New_York',
    $video_cards        = [],
    $video_options      = {},
    $wan                = false,
    $roles              = [],
) {
    #
    # Portage needs to be setup before anything else can proceed.
    #
    stage { 'setup':
        before => Stage['main'],
    }

    class { 'nest::setup':
        stage => 'setup',
    }


    #
    # Include profile components.
    #
    class { [
        "nest::arch::${arch}",
        'nest::boot',
        'nest::disk',
        'nest::environment',
        'nest::networking',
        'nest::packages',
        'nest::users',
    ]: }

    nest::role { $roles: }

    nest::role { 'ssh_server': }
}
