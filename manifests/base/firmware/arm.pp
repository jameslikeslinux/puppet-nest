class nest::base::firmware::arm {
  # For nest::base::portage::makeopts
  include 'nest::base::portage'

  case $facts['profile']['platform'] {
    /^(pinebookpro|rockpro64)$/: {
      nest::lib::toolchain { 'arm-none-eabi':
        gcc_only => true,
        before   => Exec['arm-trusted-firmware-build'],
      }

      $plat = 'rk3399'
    }

    /^(pine64|sopine)$/: {
      $plat = 'sun50i_a64'
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
    command     => "/usr/bin/make ${nest::base::portage::makeopts} E=0 PLAT=${plat}",
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
