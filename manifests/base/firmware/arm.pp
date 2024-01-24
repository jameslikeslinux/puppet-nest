class nest::base::firmware::arm (
  String $soc,
) {
  # For nest::base::portage::makeopts
  include 'nest::base::portage'

  if $soc == 'rk3399' {
    nest::lib::toolchain { 'arm-none-eabi':
      gcc_only => true,
      before   => Exec['arm-trusted-firmware-build'],
    }
  }

  vcsrepo { '/usr/src/arm-trusted-firmware':
    ensure   => latest,
    provider => git,
    source   => 'https://gitlab.james.tl/nest/forks/arm-trusted-firmware.git',
    revision => 'main',
  }
  ~>
  exec { 'arm-trusted-firmware-build':
    command     => "/usr/bin/make ${nest::base::portage::makeopts} E=0 PLAT=${soc}",
    cwd         => '/usr/src/arm-trusted-firmware',
    path        => ['/usr/lib/distcc/bin', '/usr/bin', '/bin'],
    environment => [
      'HOME=/root',                   # for distcc
      'LDFLAGS=-no-warn-rwx-segment'  # GCC 12 workaround
    ],
    timeout     => 0,
    refreshonly => true,
    noop        => !$facts['build'],
  }
}
