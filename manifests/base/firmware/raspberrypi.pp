class nest::base::firmware::raspberrypi {
  package { 'sys-boot/raspberrypi-firmware':
    ensure => installed,
  }

  # /boot is fat32
  File {
    mode  => undef,
    owner => undef,
    group => undef,
  }

  file { '/boot/u-boot.bin':
    source => '/usr/src/u-boot/u-boot.bin',
  }

  $boot_config = @(BOOT_CONFIG)
    arm_64bit=1
    arm_freq=2000
    over_voltage=6
    disable_overscan=1
    disable_splash=1
    dtparam=act_led_trigger=actpwr
    dtoverlay=vc4-kms-v3d,cma-512
    enable_uart=1
    kernel=u-boot.bin
    | BOOT_CONFIG

  file { '/boot/config.txt':
    content => $boot_config,
    require => Package['sys-boot/raspberrypi-firmware'],
  }
}
