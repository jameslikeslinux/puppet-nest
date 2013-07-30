class kernel::initrd (
    $kernel_name,
    $kernel_version,
) {
    include dracut

    exec { "dracut":
        command     => "/usr/bin/dracut --force --hostonly /boot/initramfs-${kernel_name}-${hardwaremodel}-${kernel_version} ${kernel_version}",
        require     => Class['dracut'],
        refreshonly => true,
        timeout     => 0,
    }
}
