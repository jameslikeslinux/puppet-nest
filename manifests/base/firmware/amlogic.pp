class nest::base::firmware::amlogic {
  $board = $facts['profile']['platform'] ? {
    'radxazero' => 'radxa-zero',
    default     => fail("Unsupported platform ${facts['profile']['platform']}"),
  }

  nest::lib::src_repo { '/usr/src/fip':
    url => 'https://gitlab.james.tl/nest/forks/fip.git',
    ref => 'radxa',
  }
  ~>
  exec { 'amlogic-firmware-build':
    command     => "/usr/bin/make distclean fip BOARD=${board} UBOOT_BIN=/usr/src/u-boot/u-boot.bin",
    cwd         => '/usr/src/fip',
    timeout     => 0,
    refreshonly => true,
    noop        => !$facts['build'],
  }
}
