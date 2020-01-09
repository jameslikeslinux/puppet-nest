class nest::profile::base::bootloader::systemd {
  $::partitions.each |$partition, $attributes| {
    $disk = regsubst($partition, 'p?(art)?\d+$', '')

    if $attributes['partlabel'] == "${::trusted['certname']}-efi" {
      exec { "bootctl-install-${disk}":
        command => '/usr/bin/bootctl install',
        creates => '/efi/EFI/systemd/systemd-bootx64.efi',
      }

      exec { "bootctl-update-${disk}":
        command     => '/usr/bin/bootctl update',
        refreshonly => true,
      }
    }
  }
}
