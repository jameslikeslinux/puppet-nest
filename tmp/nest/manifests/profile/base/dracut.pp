class nest::profile::base::dracut {
  package { [
    'sys-kernel/dracut',
    'sys-boot/plymouth',
  ]:
    ensure => installed,
  }

  exec { 'plymouth-set-default-theme':
    command => '/usr/sbin/plymouth-set-default-theme details',
    unless  => '/usr/sbin/plymouth-set-default-theme | /bin/grep -q details',
  }

  $base_config_content = @(EOT)
    add_dracutmodules+=" crypt "
    hostonly="yes"
    hostonly_cmdline="no"
    | EOT

  file { '/etc/dracut.conf.d/00-base.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $base_config_content,
    require => Package['sys-kernel/dracut'],
    notify  => Exec['trigger-dracut-rebuild'],
  }

  $add_devices = $::nest::luks_disks.map |$luks_disk| { "/dev/disk/by-uuid/${luks_disk[1]}" }.join(' ')
  $kernel_cmdline = $::nest::luks_disks.map |$luks_disk| { "rd.luks.uuid=${luks_disk[1]}" }.join(' ')

  $dracut_crypt_config_content = @("EOT")
    add_device+=" ${add_devices} "
    kernel_cmdline+=" ${kernel_cmdline} "
    | EOT

  file { '/etc/dracut.conf.d/10-crypt.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $dracut_crypt_config_content,
    require => Package['sys-kernel/dracut'],
    notify  => Exec['trigger-dracut-rebuild'],
  }

  $crypttab_content = $::nest::luks_disks.reduce([]) |$memo, $luks_disk| {
    concat($memo, "${luks_disk[0]} UUID=${luks_disk[1]} none luks")
  }.join("\n")

  file { '/etc/crypttab':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "${crypttab_content}\n",
    notify  => Exec['trigger-dracut-rebuild'],
  }

  exec { 'trigger-dracut-rebuild':
    command     => '/bin/rm -f /boot/dracut.built',
    refreshonly => true,
  }

  exec { 'dracut':
    command  => 'version=$(ls -t /lib/modules | head -1) && dracut --force --kver $version && touch /boot/dracut.built',
    creates  => '/boot/dracut.built',
    timeout  => 0,
    provider => shell,
    require  => [
      Package['sys-kernel/dracut'],
      Package['sys-boot/plymouth'],
      Exec['plymouth-set-default-theme'],
      Exec['trigger-dracut-rebuild'],
    ],
  }
}
