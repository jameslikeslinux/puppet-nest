class nest::base::dracut {
  package { 'sys-kernel/dracut':
    ensure => installed,
  }

  if $facts['os']['architecture'] == 'amd64' {
    package { 'sys-firmware/intel-microcode':
      ensure => installed,
    }

    $early_microcode = 'yes'
  } else {
    $early_microcode = 'no'
  }

  if $::nest::live {
    $base_config_content = @(EOT)
      add_dracutmodules+=" dmsquash-live livenet "
      omit_dracutmodules+=" zfs "
      kernel_cmdline="rd.live.overlay.thin=1 rd.vconsole.font=ter-v16b"
      | EOT
  } else {
    $base_config_content = @("EOT")
      early_microcode="${early_microcode}"
      hostonly="yes"
      hostonly_cmdline="no"
      force="yes"
      | EOT
  }




  # XXX: crypt support to be removed

  file { '/etc/dracut.conf.d/00-base.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $base_config_content,
    require => Package['sys-kernel/dracut'],
  }

  $add_devices = $::nest::luks_disks.map |$luks_disk| { "/dev/disk/by-uuid/${luks_disk[1]}" }.join(' ')
  $kernel_cmdline = $::nest::luks_disks.map |$luks_disk| { "rd.luks.uuid=${luks_disk[1]}" }.join(' ')

  $dracut_crypt_config_content = @("EOT")
    add_device+=" ${add_devices} "
    kernel_cmdline+=" ${kernel_cmdline} "
    | EOT

  file { '/etc/dracut.conf.d/10-crypt.conf':
    ensure  => absent,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $dracut_crypt_config_content,
    require => Package['sys-kernel/dracut'],
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
    ensure  => absent,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "${crypttab_content}\n",
  }
}
