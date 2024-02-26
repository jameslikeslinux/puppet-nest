class nest::base::bootloader::systemd {
  contain 'nest::base::bootloader::spec'

  if $facts['mountpoints']['/boot'] {
    if $facts['is_container'] or ($facts['dmi'] and $facts['dmi']['bios']['vendor'] == 'U-Boot') {
      $bootctl_args = '--no-variables'
    } else {
      $bootctl_args = ''
    }

    exec { 'bootctl-install':
      command => "/usr/bin/bootctl install --graceful ${bootctl_args}",
      onlyif  => '/usr/bin/bootctl is-installed | /bin/grep no',
      before  => Class['nest::base::bootloader::spec'],
    }
    ~>
    exec { 'bootctl-update':
      command     => '/usr/bin/bootctl update --graceful --no-variables',
      refreshonly => true,
    }

    # Hack bootloader updates because bootctl won't work with MBR
    # "File system '/dev/mmcblk0p1' is not on a GPT partition table."
    if $facts['profile']['platform'] == 'radxazero' {
      file { ['/boot/EFI/systemd/systemd-bootaa64.efi', '/boot/EFI/BOOT/BOOTAA64.EFI']:
        source  => '/usr/lib/systemd/boot/efi/systemd-bootaa64.efi',
        require => Exec['bootctl-install'],
      }
    }
  }
}
