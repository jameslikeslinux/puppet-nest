class nest::base::firmware::uboot (
  String                      $defconfig,
  Hash[String, Nest::Kconfig] $config = {},
) {
  # For nest::base::portage::makeopts
  include 'nest::base::portage'

  Nest::Lib::Kconfig {
    config => '/usr/src/u-boot/.config',
  }

  package { 'dev-lang/swig':
    ensure => installed,
    before => Exec['uboot-build'],
  }

  if $facts['build'] {
    $repo_ensure = latest
  } else {
    $repo_ensure = present
  }

  vcsrepo { '/usr/src/u-boot':
    ensure   => $repo_ensure,
    provider => git,
    source   => 'https://gitlab.james.tl/nest/forks/u-boot.git',
    revision => $nest::uboot_tag,
  }
  ~>
  exec { 'uboot-reset-config':
    command     => '/bin/rm -f /usr/src/u-boot/.config',
    refreshonly => true,
  }

  exec { 'uboot-defconfig':
    command => "/usr/bin/make ${defconfig}",
    cwd     => '/usr/src/u-boot',
    creates => '/usr/src/u-boot/.config',
    require => Exec['uboot-reset-config'],
    notify  => Exec['uboot-build'],
  }

  $config.each |$setting, $value| {
    nest::lib::kconfig { $setting:
      value => $value,
    }
  }

  $env_is_in_spi_flash = $facts['profile']['platform'] ? {
    'radxazero'    => undef, # setting not available
    /^raspberrypi/ => undef, # setting not available
    default        => n,
  }

  nest::lib::kconfig {
    'CONFIG_BOOTDELAY':
      value => $nest::boot_menu_delay;

    # Always use default environment to avoid divergence
    'CONFIG_ENV_IS_NOWHERE':
      value => y;
    'CONFIG_ENV_IS_IN_FAT':
      value => n;
    'CONFIG_ENV_IS_IN_SPI_FLASH':
      value => $env_is_in_spi_flash,
    ;
  }

  if $nest::uboot_tag =~ /^radxa\// {
    nest::lib::kconfig { 'CONFIG_DISABLE_CONSOLE':
      value => n,
    }

    # nest::lib::packages doesn't play nice with sloted packages
    package { [
      'dev-lang/python:2.7',
      'sys-apps/dtc',
    ]:
      ensure => installed,
      before => Exec['uboot-build'],
    }
  }

  case $facts['profile']['platform'] {
    /^(pinebookpro|rockpro64|rock4|rock5)$/: {
      $build_options = $facts['profile']['platform'] ? {
        'rock5' => "BL31=../rkbin/bin/rk35/rk3588_bl31_v1.38.elf \
                    ROCKCHIP_TPL=../rkbin/bin/rk35/rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.11.bin",
        default => 'BL31=../arm-trusted-firmware/build/rk3399/release/bl31/bl31.elf',
      }

      # Rockchip defaults to uncommon 1.5 Mbps
      nest::lib::kconfig { 'CONFIG_BAUDRATE':
        value => 115200,
      }

      package { 'dev-python/pyelftools':
        ensure => installed,
        before => Exec['uboot-build'],
      }
    }

    /^(pine64|sopine)$/: {
      $build_options = 'BL31=../arm-trusted-firmware/build/sun50i_a64/release/bl31.bin SCP=/dev/null'
    }

    default: {
      $build_options = ''
    }
  }

  exec { 'uboot-olddefconfig':
    command     => '/usr/bin/make olddefconfig',
    cwd         => '/usr/src/u-boot',
    refreshonly => true,
  }
  ~>
  exec { 'uboot-build':
    command     => "/usr/bin/make ${nest::base::portage::makeopts} ${build_options}",
    cwd         => '/usr/src/u-boot',
    path        => ['/usr/lib/distcc/bin', '/usr/bin', '/bin', '/usr/src/u-boot/scripts/dtc'],
    environment => 'HOME=/root',  # for distcc
    timeout     => 0,
    # just attempt once per config change
    refreshonly => true,
    noop        => !$facts['build'],
  }

  Exec['uboot-defconfig']
  -> Nest::Lib::Kconfig <| config == '/usr/src/u-boot/.config' |>
  ~> Exec['uboot-olddefconfig']
}
