class nest::base::dracut {
  # For nest::base::systemd::keymap
  include 'nest::base::systemd'

  package { 'sys-kernel/dracut':
    ensure => installed,
  }

  if $facts['os']['architecture'] == 'amd64' {
    package { 'sys-firmware/intel-microcode':
      ensure => installed,
    }
  }

  $vconsole_params = "rd.vconsole.font=ter-v${::nest::console_font_size}b rd.vconsole.keymap=${::nest::base::systemd::keymap}"

  if $facts['profile']['platform'] == 'live' {
    $base_config_content = @("EOT")
      add_dracutmodules+=" dmsquash-live livenet "
      omit_dracutmodules+=" zfs "
      kernel_cmdline="rd.live.overlay.overlayfs=1 ${vconsole_params}"
      | EOT
  } elsif $facts['build'] {
    $base_config_content = @("EOT")
      kernel_cmdline="${vconsole_params}"
      | EOT
  } else {
    $base_config_content = @("EOT")
      force="yes"
      hostonly="yes"
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
