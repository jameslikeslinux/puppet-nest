class profile::base::arch::beaglebone inherits profile::base::arch::base {
    portage::package { 'app-arch/lzop':
        ensure => installed,
    }

    class { 'kernel':
        kernel_name     => 'bbb',
        kernel_version  => '3.12.9-beaglebone-r20140713',
        package_name    => 'beaglebone-sources',
        package_version => '3.12.9-r20140713',
        eselect_name    => 'linux-3.12.9-beaglebone-r20140713',
        config_source   => 'puppet:///modules/profile/base/arch/beaglebone/config',
        cryptsetup      => false,
        distcc          => $::profile::base::distcc,
        require         => Portage::Package['app-arch/lzop'],
    }

    class { 'kernel::uboot':
        kernel_name     => 'bbb',
        kernel_version  => '3.12.9-beaglebone-r20140713',
        fdtfile         => 'am335x-boneblack.dtb',
    }

    class { 'boot::beaglebone':
        kernel     => 'kernel-bbb-arm-3.12.9-beaglebone-r20140713.uimage',
        initrd     => 'initramfs-bbb-arm-3.12.9-beaglebone-r20140713.uimage',
        root       => 'LABEL=rpool',
        rootfstype => 'btrfs',
        params     => $boot_params,
    }

    openrc::service { 'hwclock':
        runlevel => 'boot',
        enable   => false,
    }

    openrc::service { 'swclock':
        runlevel => 'boot',
        enable   => true,
    }

    openrc::service { 'ntp-client':
        enable  => true,
        require => Class['ntp'],
    }

    openrc::conf { 'rc_ntp_client_need':
        value => 'netif.eth0',
    }

    augeas { 'enable-serial-console-login':
        context => '/files/etc/inittab',
        changes => [
            'set s0/runlevels 12345',
            'set s0/action respawn',
            'set s0/process "/sbin/agetty -L 115200 ttyO0 vt100"',
        ],
    }
}
