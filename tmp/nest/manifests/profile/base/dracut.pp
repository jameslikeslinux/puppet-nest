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

  # XXX: Improve this
  if $::nest::live {
    $base_config_content = @(EOT)
      add_dracutmodules+=" dmsquash-live livenet "
      kernel_cmdline="rd.live.overlay.thin=1"
      | EOT

    # Fix bug in livenet module (script not executable)
    file { '/usr/lib/dracut/modules.d/90livenet/livenet-generator.sh':
      mode    => '0755',
      require => Package['sys-kernel/dracut'],
      notify  => Exec['dracut'],
    }

    # Pull in https://github.com/dracutdevs/dracut/commit/ce9a398771d6e8503d767b450282db52b7a4b482
    file { '/usr/lib/dracut/modules.d/90dmsquash-live/dmsquash-live-root.sh':
      source  => 'puppet:///modules/nest/dracut/dmsquash-live-root.sh',
      require => Package['sys-kernel/dracut'],
      notify  => Exec['dracut'],
    }
  } else {
    $base_config_content = @(EOT)
      add_dracutmodules+=" crypt "
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

  $crypttab_content = $::nest::luks_disks.map |$luks_disk| {
    "${luks_disk[0]} UUID=${luks_disk[1]} none luks"
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
      Package['sys-boot/plymouth'],
      Exec['plymouth-set-default-theme'],
    ],
  }
}
