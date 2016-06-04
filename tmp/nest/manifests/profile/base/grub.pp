class nest::profile::base::grub {
  $font = "ter-x${::nest::console_font_size}b"

  nest::portage::package_use { 'sys-boot/grub':
    use => ['grub_platforms_efi-64', 'grub_platforms_pc', 'libzfs', 'truetype'],
  }

  package { 'sys-boot/grub':
    ensure => installed,
  }

  File_line {
    path    => '/etc/default/grub',
    require => Package['sys-boot/grub'],
    notify  => Exec['grub2-mkconfig'],
  }

  $kernel_cmdline = strip("init=/usr/lib/systemd/systemd quiet splash fbcon=scrollback:1024k ${::nest::kernel_cmdline}")
  file_line { 'grub-set-kernel-cmdline':
    line    => "GRUB_CMDLINE_LINUX=\"${kernel_cmdline}\"",
    match   => '^#?GRUB_CMDLINE_LINUX=',
  }

  if $::nest::vm {
    $gfxmode    = 'GRUB_GFXMODE=1024x768'
    $gfxpayload = 'GRUB_GFXPAYLOAD_LINUX=keep'
  } else {
    $gfxmode    = '#GRUB_GFXMODE=640x480'
    $gfxpayload = '#GRUB_GFXPAYLOAD_LINUX='
  }

  file_line { 'grub-set-gfxmode':
    line  => $gfxmode,
    match => '^#?GRUB_GFXMODE',
  }

  file_line { 'grub-set-gfxpayload':
    line  => $gfxpayload,
    match => '^#?GRUB_GFXPAYLOAD_LINUX',
  }

  file_line { 'grub-set-device':
    line  => "GRUB_DEVICE=",
    match => '^#?GRUB_DEVICE=',
  }

  file_line { 'grub-set-fs':
    line  => 'GRUB_FS=',
    match => '^#?GRUB_FS=',
  }

  file_line { 'grub-set-font':
    line  => "GRUB_FONT=/boot/grub/fonts/${font}.pf2",
    match => '^#?GRUB_FONT=',
  }

  file { '/usr/sbin/grub2-auto-install':
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template('nest/grub/auto-install.sh.erb'),
  }

  exec { 'grub-install':
    command     => '/usr/sbin/grub2-auto-install',
    refreshonly => true,
    require     => [
      File['/usr/sbin/grub2-auto-install'],
      Package['sys-boot/grub'],
    ],
  }

  file { '/boot/grub':
    ensure  => directory,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    require => Exec['grub-install'],
  }

  file { [
    '/boot/grub/fonts',
    '/boot/grub/layouts',
  ]:
    ensure  => directory,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    recurse => true,
    purge   => true,
  }

  exec { 'grub2-mkfont':
    command => "/usr/bin/grub2-mkfont -o /boot/grub/fonts/${font}.pf2 /usr/share/fonts/terminus/${font}.pcf.gz",
    creates => "/boot/grub/fonts/${font}.pf2",
    require => [
      Package['sys-boot/grub'],
      File['/boot/grub/fonts'],
    ],
  }

  file { "/boot/grub/fonts/${font}.pf2":
    require => Exec['grub2-mkfont'],
  }

  file { '/boot/grub/layouts/dvorak.gkb':
    mode   => '0644',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/nest/keymaps/dvorak.gkb',
  } 

  exec { 'grub2-mkconfig':
    command     => '/usr/sbin/grub2-mkconfig -o /boot/grub/grub.cfg',
    refreshonly => true,
    require     => Exec['grub2-mkfont'],
  }
}
