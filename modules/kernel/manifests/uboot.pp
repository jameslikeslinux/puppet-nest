class kernel::uboot (
    $kernel_name,
    $kernel_version,
    $fdtfile,
) {
    $kernel = "/boot/kernel-${kernel_name}-${kernel::arch}-${kernel_version}"
    $initrd = "/boot/initramfs-${kernel_name}-${kernel::arch}-${kernel_version}"

    portage::package { 'dev-embedded/u-boot-tools':
        ensure => installed,
    }

    exec { 'remove-old-kernel-uimage':
        command     => "/bin/rm -f ${kernel}.uimage",
        refreshonly => true,
        subscribe   => Class['kernel'],
    }

    exec { 'remove-old-initrd-uimage':
        command     => "/bin/rm -f ${initrd}.uimage",
        refreshonly => true,
        subscribe   => Class['kernel::initrd'],
    }

    exec { 'make-kernel-uimage':
        command => "/usr/bin/mkimage -A ${kernel::arch} -O linux -T kernel -C none -a 0x80008000 -e 0x80008000 -n '${kernel_version}' -d ${kernel} ${kernel}.uimage",
        require => [Portage::Package['dev-embedded/u-boot-tools'], Exec['remove-old-kernel-uimage']],
        creates => "${kernel}.uimage",
    }

    exec { 'make-initrd-uimage':
        command => "/usr/bin/mkimage -A ${kernel::arch} -O linux -T ramdisk -C gzip -n '${kernel_version}' -d ${initrd} ${initrd}.uimage",
        require => [Portage::Package['dev-embedded/u-boot-tools'], Exec['remove-old-initrd-uimage']],
        creates => "${initrd}.uimage",
    }

    exec { 'make-dtbs':
        command     => '/usr/bin/make -C /usr/src/linux dtbs',
        refreshonly => true,
        subscribe   => Class['kernel'],
    }

    file { "/boot/${fdtfile}":
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        source  => "/usr/src/linux/arch/${kernel::arch}/boot/dts/${fdtfile}",
        require => Exec['make-dtbs'],
    }
}
