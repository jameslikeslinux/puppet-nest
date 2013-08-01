class profile::base::packages {
    if desktop in $profile::base::roles {
        $is_desktop = true
    }

    #
    # Has a global Portage configuration.
    #
    $use = [
        'networkmanager',
        'zsh-completion',

        $is_desktop ? {
            true    => 'pulseaudio',
            default => '',
        },

        $is_desktop ? {
            true    => 'xinerama',
            default => '',
        },
    ]

    class { 'makeconf':
        buildpkg  => true,
        getbinpkg => $profile::base::package_server,
        use       => $use,
    }


    #
    # Can use Kerberos to connect to UMD machines.
    #
    class { 'kerberos':
        default_realm => 'UMD.EDU'
    }


    #
    # Supports many standard services.
    #
    class { ['ssh', 'ssh::server']: }
    class { 'rsyslog': }
    class { 'cronie': }
    class { 'ntp': }


    #
    # Has a good text editor.
    #
    class { 'vim': }


    #
    # Has several miscellaneaous packages.
    #
    portage::package { [
        'net-misc/netkit-telnetd',
        'sys-process/glances',
        'dev-util/strace',
        'net-dns/bind-tools',
    ]:
        ensure => installed,
    }


    #
    # Uses NetworkManager for networking
    #
    class { 'networkmanager':
        kde => $is_desktop,
    }
}
