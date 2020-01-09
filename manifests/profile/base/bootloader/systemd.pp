class nest::profile::base::bootloader::systemd {
  exec { 'bootctl-install':
    command => '/usr/bin/bootctl install --graceful',
    creates => '/efi/EFI/systemd/systemd-bootx64.efi',
  }

  exec { 'bootctl-update':
    command     => '/usr/bin/bootctl update',
    refreshonly => true,
    require     => Exec['bootctl-install'],
  }

  $nvidia_params = $::nest::video_card ? {
    'nvidia' => ' nvidia-drm.modeset=1',
    default  => '',
  }

  file {
    default:
      mode  => '0644',
      owner => 'root',
      group => 'root',
    ;

    '/etc/kernel':
      ensure => directory,
    ;

    '/etc/kernel/cmdline':
      content => "root=zfs:AUTO ${::nest::profile::base::bootloader::kernel_cmdline}${nvidia_params}",
      notify  => Exec['kernel-install'],
    ;
  }

  exec { 'kernel-install':
    command     => 'version=$(ls /lib/modules | sort -V | tail -1) && kernel-install add $version /usr/src/linux/arch/x86/boot/bzImage',
    refreshonly => true,
    provider    => shell,
    require     => Exec['bootctl-install'],
  }
}
