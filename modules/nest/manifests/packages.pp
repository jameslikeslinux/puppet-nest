class nest::packages {
    class { 'private::nest::packages': }

    $is_desktop = desktop in $nest::roles
    $is_server = server in $nest::roles


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
        username  => $private::nest::packages::gmail_username,
        password  => $private::nest::packages::gmail_password,
        tls       => true,
        cacert    => 'puppet:///modules/nest/packages/EquifaxCAcert.pem',
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
        'www-client/elinks',
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


    if $nest::distcc {
        class { 'distcc':
            gui => $is_desktop,
        }

        class { 'distcc::client':
            servers => ['hawk/33'],
        }
    }
}
