class nest::profile::base::bootloader::systemd {
  exec { 'bootctl-install':
    command => '/usr/bin/bootctl install --graceful',
    unless  => '/usr/bin/bootctl is-installed | /bin/grep yes',
  }

  exec { 'bootctl-update':
    command     => '/usr/bin/bootctl update',
    refreshonly => true,
    require     => Exec['bootctl-install'],
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
      content => "root=zfs:AUTO ${::nest::profile::base::bootloader::kernel_cmdline}\n",
      notify  => Exec['kernel-install'],
    ;
  }

  $image = $facts['os']['architecture'] ? {
    'amd64'  => '/usr/src/linux/arch/x86/boot/bzImage',
    'armv7l' => '/usr/src/linux/arch/arm/boot/zImage',
  }

  exec { 'kernel-install':
    command     => "version=\$(ls /lib/modules | sort -V | tail -1) && kernel-install add \$version ${image}",
    refreshonly => true,
    provider    => shell,
    require     => Exec['bootctl-install'],
  }
}
