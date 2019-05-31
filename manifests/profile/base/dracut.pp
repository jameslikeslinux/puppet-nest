class nest::profile::base::dracut {
  # Password prompting in systemd seems to have improved in versions >=227
  # XXX: Remove this after plymouth has been removed everywhere
  package { 'sys-boot/plymouth':
    ensure => absent,
    notify => Exec['dracut'],
  }

  package { [
    'sys-kernel/dracut',
    'sys-firmware/intel-microcode',
  ]:
    ensure => installed,
  }

  if $::nest::live {
    $base_config_content = @(EOT)
      add_dracutmodules+=" dmsquash-live livenet "
      omit_dracutmodules+=" zfs "
      kernel_cmdline="rd.live.overlay.thin=1 rd.vconsole.font=ter-v16b"
      | EOT
  } else {
    $base_config_content = @(EOT)
      add_dracutmodules+=" crypt "
      early_microcode="yes"
      hostonly="yes"
      hostonly_cmdline="no"
      | EOT
  }

  file { '/etc/dracut.conf.d/00-base.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $base_config_content,
    require => Package['sys-kernel/dracut'],
    notify  => Exec['dracut'],
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
    notify  => Exec['dracut'],
  }

  $partlabels = $facts['partitions'].map |$disk, $attributes| { $attributes['partlabel'] }
  $keyfile    = ('key' in $partlabels) ? {
    true    => '/dev/disk/by-partlabel/key',
    default => 'none',
  }

  $crypttab_content = $::nest::luks_disks.map |$luks_disk| {
    "${luks_disk[0]} UUID=${luks_disk[1]} ${keyfile} luks"
  }.join("\n")

  file { '/etc/crypttab':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "${crypttab_content}\n",
    notify  => Exec['dracut'],
  }

  exec { 'dracut':
    command     => 'version=$(ls -t /lib/modules | head -1) && dracut --force --kver $version',
    refreshonly => true,
    timeout     => 0,
    provider    => shell,
    require     => [
      Package['sys-kernel/dracut'],
      Package['sys-firmware/intel-microcode'],
    ],
  }
}
