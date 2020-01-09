class nest::profile::base::bootloader::systemd {
  $::partitions.each |$partition, $attributes| {
    $disk = regsubst($partition, 'p?(art)?\d+$', '')

    if "${::trusted['certname']}-" in $attributes['partlabel'] and $attributes['partlabel'] =~ /-efi/ {
      exec { "mount-${disk}":
        command     => "/bin/mkdir /efi && /bin/mount ${partition} /efi",
        refreshonly => true,
      }

      exec { "bootctl-install-${disk}":
        command => '/usr/bin/bootctl install',
        creates => '/efi/EFI/systemd/systemd-bootx64.efi',
        require => Exec["mount-${disk}"],
        notify  => Exec["unmount-${disk}"],
      }

      exec { "bootctl-update-${disk}":
        command     => '/usr/bin/bootctl update',
        refreshonly => true,
        require     => Exec["mount-${disk}"],
        notify      => Exec["unmount-${disk}"],
      }

      exec { "unmount-${disk}":
        command     => '/bin/umount /efi && rm -rf /efi',
        refreshonly => true,
      }
    }
  }
}
