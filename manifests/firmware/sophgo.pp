class nest::firmware::sophgo {
  # For nest::base::bootloader::spec::image
  include 'nest::base::bootloader::spec'

  # /boot is fat32
  File {
    mode  => undef,
    owner => undef,
    group => undef,
  }

  nest::lib::src_repo { '/usr/src/fip':
    url => 'https://gitlab.james.tl/nest/forks/fip.git',
    ref => 'sophgo',
  }
  ->
  file { '/boot/fip.bin':
    source => '/usr/src/fip/firmware/fip.bin',
  }

  case $nest::bootloader {
    'systemd': {
      $conf_ini_kernel = "[kernel]\nname=u-boot.bin\n"
      $uboot_ensure    = present
      $uboot_source    = '/usr/src/u-boot/u-boot.bin'
      $uroot_ensure    = absent
      $uroot_source    = undef

      Class['nest::firmware::uboot']
      -> File['/boot/riscv64/u-boot.bin']
    }

    'u-root': {
      $conf_ini_kernel = ''
      $uboot_ensure    = absent
      $uboot_source    = undef
      $uroot_ensure    = present
      $uroot_source    = '/usr/src/u-root/initramfs.cpio'

      Class['nest::base::bootloader::uroot']
      -> File['/boot/riscv64/initrd.img']

      Class['nest::base::kernel']
      -> File['/boot/riscv64/riscv64_Image']
    }

    default: {
      fail("Unsupported bootloader '${nest::bootloader}'")
    }
  }

  $conf_ini_content = @("INI")
    [sophgo-config]
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

    '/boot/riscv64/initrd.img':
      ensure => $uroot_ensure,
      source => $uroot_source,
    ;

    '/boot/riscv64/riscv64_Image':
      ensure => $uroot_ensure,
      source => $nest::base::bootloader::spec::image,
    ;

    '/boot/riscv64/u-boot.bin':
      ensure => $uboot_ensure,
      source => $uboot_source,
    ;

    '/boot/riscv64/conf.ini':
      content => $conf_ini_content,
    ;
  }
}
