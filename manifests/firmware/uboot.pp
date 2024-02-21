class nest::firmware::uboot {
  unless $nest::uboot_tag {
    fail("'uboot_tag' is not set")
  }

  # For nest::base::portage::makeopts
  include 'nest::base::portage'

  Nest::Lib::Kconfig {
    config => '/usr/src/u-boot/.config',
  }

  package { 'dev-lang/swig':
    ensure => installed,
    before => Exec['uboot-build'],
  }

  nest::lib::src_repo { '/usr/src/u-boot':
    url => 'https://gitlab.james.tl/nest/forks/u-boot.git',
    ref => $nest::uboot_tag,
  }
  ~>
  exec { 'uboot-reset-config':
    command     => '/bin/rm -f /usr/src/u-boot/.config',
    refreshonly => true,
  }

  file { '/usr/src/u-boot/.defconfig':
    content => "${nest::uboot_defconfig}\n",
    notify  => Exec['uboot-reset-config'],
  }

  exec { 'uboot-defconfig':
    command => "/usr/bin/make ${nest::uboot_defconfig}",
    cwd     => '/usr/src/u-boot',
    creates => '/usr/src/u-boot/.config',
    require => Exec['uboot-reset-config'],
    notify  => Exec['uboot-build'],
  }

  $nest::uboot_config.each |$setting, $value| {
    nest::lib::kconfig { $setting:
      value => $value,
    }
  }

  $env_is_in_spi_flash = $facts['profile']['platform'] ? {
    'milkv-pioneer' => undef, # setting not available
    'radxazero'     => undef, # setting not available
    /^raspberrypi/  => undef, # setting not available
    default         => n,
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

  if $build_options =~ /arm-trusted-firmware/ {
    Class['nest::firmware::arm']
    ~> Exec['uboot-build']
  } elsif $build_options =~ /rkbin/ {
    Class['nest::firmware::rockchip']
    ~> Exec['uboot-build']
  }

  $uboot_make_cmd = @("UBOOT_MAKE")
    #!/bin/bash
    set -ex -o pipefail
    export HOME=/root PATH=/usr/lib/distcc/bin:/usr/bin:/bin
    cd /usr/src/u-boot
    make ${nest::base::portage::makeopts} ${build_options} 2>&1 | tee build.log
    | UBOOT_MAKE

  file { '/usr/src/u-boot/build.sh':
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => $uboot_make_cmd,
  }

  exec { 'uboot-olddefconfig':
    command     => '/usr/bin/make olddefconfig',
    cwd         => '/usr/src/u-boot',
    refreshonly => true,
  }
  ~>
  exec { 'uboot-build':
    command     => '/usr/src/u-boot/build.sh',
    noop        => !$facts['build'],
    refreshonly => true,
    timeout     => 0,
    require     => File['/usr/src/u-boot/build.sh'],
  }

  Exec['uboot-defconfig']
  -> Nest::Lib::Kconfig <| config == '/usr/src/u-boot/.config' |>
  ~> Exec['uboot-olddefconfig']
}
