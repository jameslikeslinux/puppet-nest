define grub::install (
    $device = $name,
) {
    include grub

    $install_command = $device ? {
        /EFI/   => "/bin/mkdir /mnt/${device} && /bin/mount LABEL=${device} /mnt/${device} && /usr/sbin/grub-install --target=x86_64-efi --efi-directory=/mnt/${device} --removable && /bin/umount /mnt/${device} && /bin/rm -rf /mnt/${device}",
        default => "/usr/sbin/grub-install --no-floppy ${device}",
    }

    exec { "grub-install-${device}":
        command     => $install_command,
        refreshonly => true,
        subscribe   => [Class['grub'], Class['boot']],
    }
}
