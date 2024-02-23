class nest::firmware::sophgo {
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

  $conf_ini_content = @(INI)
    [sophgo-config]
    [kernel]
    name=u-boot.bin
    [eof]
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

    '/boot/riscv64/u-boot.bin':
      source  => '/usr/src/u-boot/u-boot.bin',
      require => Class['nest::firmware::uboot'],
    ;

    '/boot/riscv64/conf.ini':
      content => $conf_ini_content,
    ;
  }
}
