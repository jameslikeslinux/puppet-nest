class nest::firmware::sophgo {
  # /boot is fat32
  File {
    mode  => undef,
    owner => undef,
    group => undef,
  }

  # Keep SG2042's legacy bundle independent of the maintained LinuxBoot path
  $maintained_linuxboot = $nest::bootloader == 'u-root' and $nest::soc == 'sg2042'
  $uroot_image_path = $maintained_linuxboot ? {
    true    => '/boot/riscv64/linuxboot/Image',
    default => '/boot/riscv64/riscv64_Image',
  }
  $uroot_initrd_path = $maintained_linuxboot ? {
    true    => '/boot/riscv64/linuxboot/initrd',
    default => '/boot/riscv64/initrd.img',
  }

  nest::lib::src_repo { '/usr/src/fip':
    url => 'https://gitlab.joyfullee.me/nest/forks/fip.git',
    ref => 'sophgo',
  }
  ->
  file { '/boot/fip.bin':
    source => '/usr/src/fip/firmware/fip.bin',
  }

  case $nest::bootloader {
    'systemd': {
      $conf_ini_kernel = "[kernel]\nname=u-boot.bin\n\n"
      $uboot_ensure    = present
      $uboot_source    = '/usr/src/u-boot/u-boot.bin'
      $uroot_ensure    = absent
      $uroot_image     = undef
      $uroot_source    = undef

      Class['nest::firmware::uboot']
      -> File['/boot/riscv64/u-boot.bin']
    }

    'u-root': {
      include nest::base::bootloader # safe for stage2

      $conf_ini_kernel = ''
      $uboot_ensure    = absent
      $uboot_source    = undef
      $uroot_ensure    = present
      $uroot_image     = '/usr/src/u-root-linux/arch/riscv/boot/Image'
      $uroot_source    = '/usr/src/u-root/initramfs.cpio'

      Class['nest::base::bootloader::uroot']
      -> File[$uroot_initrd_path, $uroot_image_path]
    }

    default: {
      fail("Unsupported bootloader '${nest::bootloader}'")
    }
  }

  $conf_ini_dtb = $maintained_linuxboot ? {
    true    => 'sg2042-milkv-pioneer.dtb',
    default => $nest::dtb_file.basename,
  }
  $conf_ini_boot = $maintained_linuxboot ? {
    true    => "[boot]\ndefault=bundle\n\n",
    default => '',
  }

  # See: https://github.com/sophgo/sophgo-doc/blob/main/SG2042/HowTo/Configuration%20Info%20in%20INI%20file.rst
  $conf_ini_content = @("INI")
    [sophgo-config]

    ${conf_ini_boot}[devicetree]
    name=${conf_ini_dtb}

    ${conf_ini_kernel}[eof]
    | INI

  file {
    '/boot/zsbl.bin':
      source  => '/usr/src/zsbl/zsbl.bin',
      require => Class['nest::firmware::zsbl'],
    ;

    '/boot/riscv64/fw_dynamic.bin':
      source  => '/usr/src/opensbi/build/platform/generic/firmware/fw_dynamic.bin',
      require => Class['nest::firmware::opensbi'],
    ;

    $uroot_initrd_path:
      ensure => $uroot_ensure,
      source => $uroot_source,
    ;

    $uroot_image_path:
      ensure => $uroot_ensure,
      source => $uroot_image,
    ;

    '/boot/riscv64/u-boot.bin':
      ensure => $uboot_ensure,
      source => $uboot_source,
    ;

    '/boot/riscv64/conf.ini':
      content => $conf_ini_content,
    ;
  }

  if $maintained_linuxboot {
    $linuxboot_args = $nest::kernel_cmdline.filter |$arg| {
      $arg =~ /^(console=|loglevel=|initcall_debug($|=)|nvme_core\.default_ps_max_latency_us=)/
    }.join(' ')
    $linuxboot_bundle = @("BUNDLE")
      kernel=/riscv64/linuxboot/Image
      dtb=/riscv64/${nest::dtb_file.basename}
      ramfs=/riscv64/linuxboot/initrd
      bootargs=${linuxboot_args} earlycon=sbi root=/dev/ram0 ro
      | BUNDLE
    $runtime_bundle = @("BUNDLE")
      kernel=/${facts['machine_id']}/${nest::kernel_version}/linux
      dtb=/riscv64/${nest::dtb_file.basename}
      ramfs=/${facts['machine_id']}/${nest::kernel_version}/initrd
      bootargs=${nest::base::bootloader::kernel_cmdline}
      | BUNDLE

    file { '/boot/riscv64/linuxboot':
      ensure => directory,
      before => File[$uroot_image_path, $uroot_initrd_path],
    }
    file { '/boot/riscv64/boot-bundle.conf':
      content => $linuxboot_bundle,
      require => [File[$uroot_image_path, $uroot_initrd_path], Class['nest::base::firmware']],
    }
    # Retain the serial-selectable direct runtime bypass for development
    file { '/boot/riscv64/test-bundle.conf':
      content => $runtime_bundle,
      require => [Class['nest::base::firmware'], Exec['kernel-install']],
    }
    File['/boot/riscv64/conf.ini'] {
      require => File['/boot/zsbl.bin', '/boot/riscv64/boot-bundle.conf'],
    }
  }
}
