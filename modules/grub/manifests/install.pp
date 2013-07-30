define grub::install (
    $device = $name,
) {
    include grub

    exec { "grub-install-${device}":
        command     => "/usr/sbin/grub-install --no-floppy ${device}",
        refreshonly => true,
        subscribe   => Class['grub']
    }
}
