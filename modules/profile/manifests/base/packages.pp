class profile::base::packages {
    class { 'private::profile::base::packages': }

    $is_desktop = desktop in $profile::base::roles
    $is_server = server in $profile::base::roles


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
        'app-arch/unrar',
        'app-misc/screen',
        'dev-util/strace',
        'net-dns/bind-tools',
        'net-misc/netkit-telnetd',
        'sys-apps/hdparm',
        'sys-apps/pv',
        'sys-fs/dosfstools',
        'sys-process/glances',
        'sys-process/lsof',
    ]:
        ensure => installed,
    }

    portage::package { 'app-arch/p7zip':
        ensure => installed,
        use    => '-kde',
    }

    class { 'sysstat':
        sar => $is_server,
    }

    class { 'vcs': }


    if $profile::base::distcc {
        class { 'distcc':
            gui => $is_desktop,
        }

        class { 'distcc::client':
            servers => ['hawk/33'],
        }
    }
}
