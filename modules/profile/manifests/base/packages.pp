class profile::base::packages {
    class { 'private::profile::base::packages': }

    $is_desktop = desktop in $profile::base::roles
    $is_server  = server  in $profile::base::roles

    #
    # Has a global Portage configuration.
    #
    $use = [
        'zsh-completion',

        $is_desktop ? {
            true    => 'networkmanager',
            default => [],
        },

        $is_desktop ? {
            true    => 'pulseaudio',
            default => [],
        },

        $is_desktop ? {
            true    => 'xinerama',
            default => [],
        },
    ]

    class { 'makeconf':
        buildpkg  => true,
        getbinpkg => $profile::base::package_server,
        use       => flatten($use),
    }



    #
    # Supports many standard services.
    #
    class { 'rsyslog': }
    class { 'cronie': }
    class { 'ntp': }


    #
    # Can relay mail through Gmail...
    #
    class { 'postfix::relay':
        relayhost => '[smtp.googlemail.com]:submission',
        username  => $private::profile::base::packages::gmail_username,
        password  => $private::profile::base::packages::gmail_password,
        tls       => true,
        cacert    => 'puppet:///modules/profile/base/packages/EquifaxCAcert.pem',
    }


    #
    # but not if it's for 'example.com'.
    #
    class { 'postfix::transport':
        map => {'example.com' => 'discard:'},
    }


    #
    # Has a good text editor.
    #
    class { 'vim': }


    #
    # Has several miscellaneaous packages.
    #
    portage::package { [
        'app-misc/screen',
        'dev-util/strace',
        'net-dns/bind-tools',
        'net-misc/netkit-telnetd',
        'sys-apps/hdparm',
        'sys-process/glances',
        'sys-process/lsof',
    ]:
        ensure => installed,
    }

    class { 'sysstat':
        sar => $is_server,
    }

    class { 'vcs': }

    class { 'java':
        nsplugin => $is_desktop,
    }
}
