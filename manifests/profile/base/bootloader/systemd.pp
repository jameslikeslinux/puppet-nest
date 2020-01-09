class nest::profile::base::bootloader::systemd {
  exec { 'bootctl-install':
    command => '/usr/bin/bootctl install',
    creates => '/efi/EFI/systemd/systemd-bootx64.efi',
  }

  exec { 'bootctl-update':
    command     => '/usr/bin/bootctl update',
    refreshonly => true,
    require     => Exec['bootctl-install'],
  }
}
