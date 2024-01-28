class nest::base::firmware::amlogic {
  $board = $facts['profile']['platform'] ? {
    'radxazero' => 'radxa-zero',
    default     => fail("Unsupported platform ${facts['profile']['platform']}"),
  }

  vcsrepo { '/usr/src/fip':
    ensure   => latest,
    provider => git,
    source   => 'https://gitlab.james.tl/nest/forks/fip.git',
    revision => 'radxa',
  }
  ~>
  exec { 'amlogic-firmware-build':
    command     => "/usr/bin/make fip BOARD=${board} UBOOT_BIN=/usr/src/u-boot/u-boot.bin",
    cwd         => '/usr/src/fip',
    timeout     => 0,
    refreshonly => true,
    noop        => !$facts['build'],
  }
}
