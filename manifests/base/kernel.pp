class nest::base::kernel {
  # For nest::base::portage::makeopts
  include 'nest::base::portage'

  Nest::Lib::Kconfig {
    config => '/usr/src/linux/.config',
  }

  nest::lib::package { 'sys-devel/bc':
    ensure => installed,
    before => Exec['kernel-build'],
  }

  vcsrepo { '/usr/src/linux':
    ensure   => latest,
    provider => git,
    source   => 'https://gitlab.james.tl/nest/forks/linux.git',
    revision => $nest::kernel_tag,
  }
  ~>
  exec { 'kernel-reset-config':
    command     => '/bin/rm -f /usr/src/linux/.config',
    refreshonly => true,
  }
  ->  # sources w/o config, just like a provided package
  file_line { 'package.provided-kernel':
    path  => '/etc/portage/profile/package.provided',
    line  => "sys-kernel/vanilla-sources-${nest::kernel_version}",
    match => '^sys-kernel/vanilla-sources-',
  }

  file { '/usr/src/linux/.scmversion':
    # Prevent addition of '+' to kernel version in git-based source trees
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    require => Vcsrepo['/usr/src/linux'],
    before  => Exec['kernel-build'],
  }

  $defconfig = $facts['profile']['platform'] ? {
    'beagleboneblack' => 'multi_v7_defconfig',
    'pinebookpro'     => 'defconfig',
    'raspberrypi'     => 'bcm2711_defconfig',
    'rock5'           => 'rockchip_linux_defconfig',
    'sopine'          => 'defconfig',
    default           => 'defconfig kvm_guest.config',
  }

  exec { 'kernel-defconfig':
    command => "/usr/bin/make ${defconfig}",
    cwd     => '/usr/src/linux',
    creates => '/usr/src/linux/.config',
    require => Exec['kernel-reset-config'],
    notify  => Exec['kernel-build'],
  }

  $nest::kernel_config.each |$config, $value| {
    nest::lib::kconfig { $config:
      value => $value,
    }
  }

  if $nest::bootloader == 'systemd' {
    nest::lib::kconfig { 'CONFIG_EFI_STUB':
      value => y,
    }
  }

  # Workaround https://sourceware.org/bugzilla/show_bug.cgi?id=26256
  if $nest::kernel_tag =~ /^(raspberrypi|radxa)\// {
    nest::lib::package { 'sys-devel/lld':
      ensure => installed,
      before => Exec['kernel-build'],
    }

    $lld_override = 'LD=ld.lld'

    Package_env <| title == 'sys-fs/zfs-kmod' |> {
      env +> 'lld.conf',
    }
  }

  # Required for mkimage(1)
  if $nest::kernel_tag =~ /^radxa\// {
    nest::lib::package { 'dev-embedded/u-boot-tools':
      ensure => installed,
      before => Exec['kernel-build'],
    }
  }

  $kernel_make_cmd = @("KERNEL_MAKE")
    set -o pipefail
    make ${nest::base::portage::makeopts} ${lld_override} olddefconfig all modules_install 2>&1 |
    tee build.log
    | KERNEL_MAKE

  exec { 'kernel-olddefconfig':
    command     => '/usr/bin/make olddefconfig',
    cwd         => '/usr/src/linux',
    refreshonly => true,
  }
  ~>
  exec { 'kernel-build':
    command     => $kernel_make_cmd,
    cwd         => '/usr/src/linux',
    path        => ['/usr/lib/distcc/bin', '/usr/lib/llvm/15/bin', '/usr/lib/llvm/14/bin', '/usr/bin', '/bin'],
    environment => 'HOME=/root',  # for distcc
    timeout     => 0,
    refreshonly => true,
    noop        => !$facts['build'],
    notify      => Class['nest::base::dracut'],
    provider    => shell,
  }
  ~>
  exec { 'module-rebuild':
    command     => '/usr/bin/emerge --buildpkg n --usepkg n @module-rebuild',
    timeout     => 0,
    refreshonly => true,
    noop        => str2bool($facts['skip_module_rebuild']),
    notify      => Class['nest::base::dracut'],
  }
  ->
  nest::lib::package { 'sys-fs/zfs-kmod':
    ensure => installed,
    binpkg => false,
  }

  Exec['kernel-defconfig']
  -> Nest::Lib::Kconfig <| config == '/usr/src/linux/.config' |>
  ~> Exec['kernel-olddefconfig']


  #
  # XXX Cleanup
  #
  ['gentoo-sources', 'raspberrypi-sources'].each |$package| {
    exec { "remove-${package}":
      command => "/usr/bin/emerge --depclean '${package}'",
      onlyif  => "/usr/bin/eix --quiet --installed --exact '${package}'",
      require => File_line['package.provided-kernel'],
    }
  }

  # Replace old symlink
  file { '/usr/src/linux':
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
    before => Vcsrepo['/usr/src/linux'],
  }
}
