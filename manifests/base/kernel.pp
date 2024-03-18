class nest::base::kernel {
  Nest::Lib::Kconfig {
    config => '/usr/src/linux/.config',
  }

  $arch = $facts['profile']['architecture'] ? {
    'amd64' => 'x86_64',
    default => $facts['profile']['architecture'],
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
    $lld_override = "LD=${facts['llvm_ld']}"

    file { '/etc/portage/env/lld.conf':
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => "${lld_override}\nEXTRA_EMAKE=\"${lld_override}\"\n",
    }

    Package_env <| title == 'sys-fs/zfs-kmod' |> {
      env +> 'lld.conf',
    }
  } else {
    $lld_override = ''
  }

  case $nest::kernel_tag {
    /^radxa\//: {
      # Required for mkimage(1)
      nest::lib::package { 'dev-embedded/u-boot-tools':
        ensure => installed,
        before => Nest::Lib::Build['kernel'],
      }

      # Ignore warning on newer GCC
      $cflags = [
        '-Wno-address',
        '-Wno-array-compare',
        '-Wno-dangling-pointer',
        '-Wno-enum-int-mismatch',
        '-Wno-implicit-fallthrough',
        '-Wno-int-in-bool-context',
        '-Wno-stringop-overread',
        '-Wno-tautological-compare',
      ]
      $cflags_override = "KCFLAGS=\"${cflags.join(' ')}\""

      file { '/etc/portage/env/kcflags.conf':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => "${cflags_override}\n",
      }

      Package_env <| title == 'sys-fs/zfs-kmod' |> {
        env +> 'kcflags.conf',
      }
    }

    /^sophgo\//: {
      # Hide known warnings from Xe backport effort
      $cflags_override = 'KCFLAGS="-Wno-discarded-qualifiers -Wno-address"'
    }

    default: {
      $cflags_override = ''
    }
  }

  nest::lib::package { 'sys-devel/bc':
    ensure => installed,
    before => Nest::Lib::Build['kernel'],
  }

  nest::lib::src_repo { '/usr/src/linux':
    url => 'https://gitlab.james.tl/nest/forks/linux.git',
    ref => $nest::kernel_tag,
  }
  ~>
  nest::lib::build { 'kernel':
    args      => "LOCALVERSION= ${lld_override} ${cflags_override} olddefconfig all modules_install",
    defconfig => $nest::kernel_defconfig,
    dir       => '/usr/src/linux',
    makeargs  => "ARCH=${arch}",
    notify    => Class['nest::base::dracut'], # in case module-rebuild is noop
  }
  ->
  nest::lib::package { 'sys-fs/zfs-kmod':
    ensure => latest,
    binpkg => false,
    build  => !!$facts['build'],
    notify => Class['nest::base::dracut'],
  }
  ->
  exec { 'module-rebuild':
    command     => '/usr/bin/emerge --buildpkg n --usepkg n @module-rebuild',
    noop        => !$facts['build'] or str2bool($facts['skip_module_rebuild']),
    refreshonly => true,
    timeout     => 0,
    subscribe   => Nest::Lib::Build['kernel'],
    notify      => Class['nest::base::dracut'],
  }

  # Sources w/o config, just like a provided package
  file_line { 'package.provided-kernel':
    path    => '/etc/portage/profile/package.provided',
    line    => "sys-kernel/vanilla-sources-${nest::kernel_version.regsubst('-', '_')}",
    match   => '^sys-kernel/vanilla-sources-',
    require => Nest::Lib::Src_repo['/usr/src/linux'],
    before  => Nest::Lib::Build['kernel'],
  }
}
