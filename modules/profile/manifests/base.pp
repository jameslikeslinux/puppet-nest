class profile::base (
    $arch               = x86,
    $boot_disk          = undef,
    $boot_decrypt       = undef,
    $boot_options       = [],
    $default_sound_card = undef,
    $distcc             = false,
    $dpi                = undef,
    $keymap             = 'dvorak',
    $lcd                = true,
    $package_server     = undef,
    $remote_backup      = false,
    $resolution         = undef,
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

    class { 'profile::base::setup':
        stage => 'setup',
    }


    #
    # Include profile components.
    #
    class { [
        "profile::base::arch::${arch}",
        'profile::base::boot',
        'profile::base::disk',
        'profile::base::environment',
        'profile::base::networking',
        'profile::base::packages',
        'profile::base::users',
    ]: }

    profile::role { $roles: }

    profile::role { 'ssh_server': }
}
