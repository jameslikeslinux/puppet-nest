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

  if $facts['live'] {
    $base_config_content = @(EOT)
      add_dracutmodules+=" dmsquash-live livenet "
      omit_dracutmodules+=" zfs "
      kernel_cmdline="rd.live.overlay.thin=1 rd.vconsole.font=ter-v16n"
      | EOT
  } else {
    $base_config_content = @("EOT")
      early_microcode="${early_microcode}"
      hostonly="yes"
      hostonly_cmdline="no"
      force="yes"
      | EOT
  }

  file { '/etc/dracut.conf.d/00-base.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $base_config_content,
    require => Package['sys-kernel/dracut'],
  }

  if $::platform == 'pinebookpro' {
    $pinebookpro_config_content = @(PBP_CONF)
      add_drivers+=" fusb302 rockchipdrm "
      install_items+=" /lib/firmware/rockchip/dptx.bin "
      | PBP_CONF

    file { '/etc/dracut.conf.d/10-pinebookpro.conf':
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => $pinebookpro_config_content,
      require => Package['sys-kernel/dracut'],
    }
  }
}
