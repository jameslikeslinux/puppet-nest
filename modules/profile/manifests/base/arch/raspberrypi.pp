class profile::base::arch::raspberrypi {
    class { 'kernel':
        kernel_name     => 'rpi',
        kernel_version  => '3.6.11-raspberrypi-r20130711',
        package_name    => 'raspberrypi-sources',
        package_version => '3.6.11-r20130711',
        eselect_name    => 'linux-3.6.11-raspberrypi-r20130711',
        config_source   => 'puppet:///modules/profile/base/arch/raspberrypi/config',
        cryptsetup      => false,
        distcc          => $::profile::base::distcc,
    }

    class { 'boot::raspberrypi':
        kernel  => 'kernel-rpi-arm-3.6.11-raspberrypi-r20130711',
        initrd  => 'initramfs-rpi-arm-3.6.11-raspberrypi-r20130711',
        root    => 'zfs',
        params  => ['elevator=noop'],
    }

    class { '::raspberrypi': }

#    class { '::raspberrypi::overclock':
#        setting => medium,
#    }

    raspberrypi::config { 'disable_overscan':
        value => '1',
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
        value => 'dhcpcd',
    }
}
