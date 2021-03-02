class nest::base::firmware::arm {
  # For nest::base::portage::makeopts
  include '::nest::base::portage'

  nest::lib::toolchain { 'arm-none-eabi':
    gcc_only => true,
  }

  vcsrepo { '/usr/src/arm-trusted-firmware':
    ensure   => latest,
    provider => git,
    source   => 'https://gitlab.james.tl/nest/forks/arm-trusted-firmware.git',
    revision => 'main',
  }
  ~>
  exec { 'arm-trusted-firmware-build':
    command     => "/usr/bin/make ${::nest::base::portage::makeopts} PLAT=rk3399",
    cwd         => '/usr/src/arm-trusted-firmware',
    path        => ['/usr/lib/distcc/bin', '/usr/bin', '/bin'],
    environment => 'HOME=/root',  # for distcc
    timeout     => 0,
    refreshonly => true,
    noop        => !$facts['build'],
    require     => Nest::Lib::Toolchain['arm-none-eabi'],
  }
}
