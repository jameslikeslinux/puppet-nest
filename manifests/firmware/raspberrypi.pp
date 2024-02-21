class nest::firmware::raspberrypi {
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
    source  => '/usr/src/u-boot/u-boot.bin',
    require => Class['nest::firmware::uboot'],
  }

  file { '/boot/config.txt':
    content => epp('nest/raspberrypi/config.txt.epp'),
    require => Package['sys-boot/raspberrypi-firmware'],
  }
}
