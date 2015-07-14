class nest::setup {
    #
    # Setup root user
    # (root user is a dependency of some files in the portage module)
    #
    include private::nest::users

    # We need to set the root shell to /bin/zsh, but it doesn't exist
    # yet and we can't install it until Portage is setup (i.e. not yet).
    class { 'zsh::fake': }

    users::user { 'root':
        uid      => 0,
        gid      => 0,
        fullname => 'root',
        shell    => '/bin/zsh',
        home     => '/root',
        profile  => 'git://github.com/MrStaticVoid/profile.git',
        password => $::private::nest::users::root_pwhash,
        require  => Class['zsh::fake'],
    }


    #
    # Set global portage configuration
    #
    $is_desktop = desktop in $nest::roles
    $is_compile_server = compile_server in $nest::roles

    if $is_desktop {
        # XXX: This is kind of ugly...

        $flavor = "funtoo/1.0/linux-gnu/flavor/desktop"
        exec { "eselect-profile-flavor":
            command => "/usr/bin/eselect profile set-flavor '${flavor}'",
            unless  => "/usr/bin/eselect profile show | /bin/grep '${flavor}'",
            notify  => Class['portage'],
        }

        $mixin = "funtoo/1.0/linux-gnu/mix-ins/kde"
        exec { "eselect-profile-mixin-kde":
            command => "/usr/bin/eselect profile add '${mixin}'",
            unless  => "/usr/bin/eselect profile show | /bin/grep '${mixin}'",
            notify  => Class['portage'],
        }

        portage::makeconf { 'video_cards':
            content => join($nest::video_cards, ' '),
        }
    }

    if $is_compile_server {
        overlay { 'local-crossdev':
            target => '/usr/local/portage-crossdev',
            before => Class['makeconf'],
        }
    }

    $use = [
        'zsh-completion',

        $is_desktop ? {
            true    => ['networkmanager', 'vdpau', 'xinerama'],
            default => [],
        },
    ]

    $overlays = [
        $is_compile_server ? {
            true    => '/usr/local/portage-crossdev',
            default => [],
        },
    ]

    $makejobs_non_distcc = $processorcount + 1
    $makejobs_distcc = 33

    class { 'makeconf':
        debug     => true,
        buildpkg  => true,
        getbinpkg => $nest::package_server,
        distcc    => $nest::distcc,
        makejobs  => $nest::distcc ? {
            false   => $makejobs_non_distcc,
            default => $makejobs_distcc,
        },
        use       => flatten($use),
        overlays  => flatten($overlays),
    }

   
    #
    # Configure portage
    #
    class { 'portage':
        eselect_ensure => installed,
        stage          => 'setup',
    }

    #
    # XXX: This class is deprecated, but as long as it exists, we need
    # it to run in the setup stage.
    #
    class { 'concat::setup': }
}
