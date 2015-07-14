class nest::arch::beaglebone inherits nest::arch::base {
    # /usr/portage/profiles/funtoo/1.0/linux-gnu/arch/arm-32bit/package.mask/funtoo-cautionary:
    # Jean-Francis Roy <jeanfrancis@funtoo.org> (6 Jul 2014)
    # FL-1332: Mask =dev-libs/lzo-2.08* as it breaks OpenVPN
    package_unmask { 'dev-libs/lzo':
        version => '=2.08*',
        before  => Portage::Package['app-arch/lzop'],
    }

    portage::package { 'app-arch/lzop':
        ensure => installed,
    }

    # lvm2 with USE=thin depends on thin-provisioning-tools, which fails
    # to compile on ARM.
    # See: https://github.com/jthornber/thin-provisioning-tools/issues/22
    package_use { 'sys-fs/lvm2':
        use    => '-thin',
        before => Class['kernel'],
    }

    class { 'kernel':
        kernel_name     => 'bbb',
        kernel_version  => '3.14.43-beagleboard-r67',
        package_name    => 'beagleboard-sources',
        package_version => '3.14.43-r67',
        eselect_name    => 'linux-3.14.43-beagleboard-r67',
        config_source   => 'puppet:///modules/nest/arch/beaglebone/config',
        cryptsetup      => false,
        distcc          => $::nest::distcc,
        require         => Portage::Package['app-arch/lzop'],
    }

    class { 'kernel::dtbs':
        fdtfile => 'am335x-boneblack.dtb',
    }

    class { 'boot::beaglebone':
        kernel => 'kernel-bbb-arm-3.14.43-beagleboard-r67',
        initrd => 'initramfs-bbb-arm-3.14.43-beagleboard-r67',
        root   => 'zfs',
        params => $boot_params,
    }

    class { 'zfs::smallpc': }

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
}
