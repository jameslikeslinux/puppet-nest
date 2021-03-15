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
    $base_config_content = @("EOT")
      add_dracutmodules+=" dmsquash-live livenet "
      omit_dracutmodules+=" zfs "
      kernel_cmdline="rd.live.overlay.overlayfs=1 rd.vconsole.font=ter-v${::nest::console_font_size}b"
      | EOT
  } elsif $facts['build'] {
    $base_config_content = @("EOT")
      early_microcode="${early_microcode}"
      force="yes"
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

  # During boot, systemd-udev-trigger -> systemd-udev-settle ->
  # zfs-import-cache, but for some reason, persistent device labels aren't
  # processed in time by the trigger-settle loop.  Triggering changes seems to
  # fix the problem.
  file_line { 'systemd-udev-trigger-changes':
    path  => '/lib/systemd/system/systemd-udev-trigger.service',
    after => 'ExecStart=/bin/udevadm trigger --type=devices --action=add',
    line  => 'ExecStart=/bin/udevadm trigger --type=devices --action=change',
  }
}
