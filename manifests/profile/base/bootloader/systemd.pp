class nest::profile::base::bootloader::systemd {
  if $facts['virtual'] == 'lxc' or $facts['os']['architecture'] == 'armv7l' {
    $bootctl_args = '--no-variables'
  } else {
    $bootctl_args = ''
  }

  exec { 'bootctl-install':
    command => "/usr/bin/bootctl install --graceful ${bootctl_args}",
    unless  => '/usr/bin/bootctl is-installed | /bin/grep yes',
  }

  exec { 'bootctl-update':
    command     => "/usr/bin/bootctl update ${bootctl_args}",
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
