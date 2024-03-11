class nest::node::eagle_console {
  # Avoid using UART on this node
  file_line {
    default:
      path   => '/usr/src/u-boot/board/raspberrypi/rpi/rpi.env',
      notify => Exec['uboot-build'],
    ;

    'u-boot-rpi.env-stdin':
      line  => 'stdin=usbkbd',
      match => '^stdin=',
    ;

    'u-boot-rpi.env-stdout':
      line  => 'stdout=vidconsole',
      match => '^stdout=',
    ;

    'u-boot-rpi.env-stderr':
      line  => 'stderr=vidconsole',
      match => '^stderr=',
    ;
  }

  # Try to reject UART input stopping autoboot
  nest::lib::kconfig {
    default:
      config => '/usr/src/u-boot/.config';
    'CONFIG_AUTOBOOT_KEYED':
      value => y;
    'CONFIG_AUTOBOOT_KEYED_CTRLC':
      value => y,
    ;
  }

  nest::lib::package { [
    'dev-libs/libgpiod',
    'net-dialup/minicom',
  ]:
    ensure => installed,
  }
}
