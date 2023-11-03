class nest::base::firmware::uboot {
  # For nest::base::portage::makeopts
  include 'nest::base::portage'

  Nest::Lib::Kconfig {
    config => '/usr/src/u-boot/.config',
  }

  package { 'dev-lang/swig':
    ensure => installed,
    before => Exec['uboot-build'],
  }

  vcsrepo { '/usr/src/u-boot':
    ensure   => latest,
    provider => git,
    source   => 'https://gitlab.james.tl/nest/forks/u-boot.git',
    revision => $nest::uboot_tag,
  }
  ~>
  exec { 'uboot-reset-config':
    command     => '/bin/rm -f /usr/src/u-boot/.config',
    refreshonly => true,
  }

  $defconfig = $facts['profile']['platform'] ? {
    'beagleboneblack' => 'am335x_evm_defconfig',
    'pine64'          => 'pine64-lts_defconfig',
    'pinebookpro'     => 'pinebook-pro-rk3399_defconfig',
    'raspberrypi4'    => 'rpi_arm64_defconfig',
    'rock5'           => 'rock-5b-rk3588_defconfig',
    'rockpro64'       => 'rockpro64-rk3399_defconfig',
    'sopine'          => 'sopine_baseboard_defconfig',
  }

  exec { 'uboot-defconfig':
    command => "/usr/bin/make ${defconfig}",
    cwd     => '/usr/src/u-boot',
    creates => '/usr/src/u-boot/.config',
    require => Exec['uboot-reset-config'],
    notify  => Exec['uboot-build'],
  }

  $env_is_in_spi_flash = $facts['profile']['platform'] ? {
    'raspberrypi4' => undef,
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
    /^(pinebookpro|rockpro64)$/: {
      $build_options = 'BL31=../arm-trusted-firmware/build/rk3399/release/bl31/bl31.elf'

      # RK3399 defaults to uncommon 1.5 Mbps
      nest::lib::kconfig { 'CONFIG_BAUDRATE':
        value => 115200,
      }

      package { 'dev-python/pyelftools':
        ensure => installed,
        before => Exec['uboot-build'],
      }
    }

    'raspberrypi4': {
      $build_options = ''

      # Fails with "Unknown partition table type 0"
      nest::lib::kconfig { 'CONFIG_MMC_SDHCI_SDMA':
        value => n,
      }
    }

    'rock5': {
      $build_options = 'BL31=../rkbin/bin/rk35/rk3588_bl31_v1.28.elf spl/u-boot-spl.bin u-boot.dtb u-boot.itb'
      $mkimage = @(MKIMAGE/L)
        /usr/src/u-boot/tools/mkimage -n rk3588 -T rksd \
        -d ../rkbin/bin/rk35/rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.08.bin:spl/u-boot-spl.bin idbloader.img
        |-MKIMAGE

      # RK3588 defaults to uncommon 1.5 Mbps
      nest::lib::kconfig { 'CONFIG_BAUDRATE':
        value => 115200,
      }

      # See https://github.com/radxa/build/blob/debian/mk-uboot.sh
      exec { 'uboot-mkimage':
        command     => $mkimage,
        cwd         => '/usr/src/u-boot',
        refreshonly => true,
        subscribe   => Exec['uboot-build'],
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
