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

        $flavor = 'desktop'
        exec { 'epro-flavor':
            command => "/usr/sbin/epro profile '${flavor}'",
            unless  => "/usr/sbin/epro | /bin/grep '.*flavor.*:.*${flavor}'",
            notify  => Class['portage'],
        }

        $mixins = ['kde', 'kde-plasma-5']
        $mixins.each |$mixin| {
            exec { "epro-mixin-${mixin}":
                command => "/usr/sbin/epro mix-ins '+${mixin}'",
                unless  => "/usr/sbin/epro | /bin/grep '.*mix-ins.*:.*${mixin}'",
                notify  => Class['portage'],
            }
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

    $makejobs_by_memory = ceiling($memory['system']['total_bytes'] / (512.0 * 1024 * 1024))
    $makejobs_non_distcc = $processorcount + 1
    $makejobs_distcc = 33

    $makejobs_non_distcc_min = ($makejobs_by_memory < $makejobs_non_distcc) ? {
        true    => $makejobs_by_memory,
        default => $makejobs_non_distcc,
    }

    $makejobs_distcc_min = ($makejobs_by_memory < $makejobs_distcc) ? {
        true    => $makejobs_by_memory,
        default => $makejobs_distcc,
    }

    class { 'makeconf':
        debug     => true,
        buildpkg  => true,
        getbinpkg => $nest::package_server,
        distcc    => $nest::distcc,
        makejobs  => $nest::distcc ? {
            false   => $makejobs_non_distcc_min,
            default => $makejobs_distcc_min,
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
