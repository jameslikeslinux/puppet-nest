class nest::base::firmware::arm {
  nest::lib::toolchain { 'arm-none-eabi':
    gcc_only => true,
  }

  vcsrepo { '/usr/src/arm-trusted-firmware':
    ensure   => present,
    provider => git,
    source   => 'https://github.com/ARM-software/arm-trusted-firmware.git',
    revision => 'v2.4',
  }

  include '::nest::base::portage'
  exec { "/usr/bin/make ${::nest::base::portage::makeopts} PLAT=rk3399":
    cwd         => '/usr/src/arm-trusted-firmware',
    path        => ['/usr/lib/distcc/bin', '/usr/bin', '/bin'],
    environment => 'HOME=/root',  # for distcc
    timeout     => 0,
    creates     => '/usr/src/arm-trusted-firmware/build/rk3399/release/bl31/bl31.elf',
    subscribe   => Vcsrepo['/usr/src/arm-trusted-firmware'],
    require     => Nest::Lib::Toolchain['arm-none-eabi'],
  }
}
