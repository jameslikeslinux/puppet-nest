class nest::firmware::zsbl {
  # For nest::base::portage::makeopts
  include 'nest::base::portage'

  # Install bare-metal toolchain with newlib C library
  # - set 'libdir' to workaround https://bugs.gentoo.org/908455
  # - disable multilib so newlib doesn't fail trying to build for rv32
  # - with /usr/bin/ld for PIE support
  nest::lib::toolchain { 'riscv64-unknown-elf':
    gcc_conf => '--libdir=/usr/lib64 --disable-multilib --with-ld=/usr/bin/ld',
    before   => Exec['zsbl-build'],
  }

  Nest::Lib::Kconfig {
    config => '/usr/src/zsbl/.config',
  }

  nest::lib::src_repo { '/usr/src/zsbl':
    url => 'https://gitlab.james.tl/nest/forks/zsbl.git',
    ref => 'sophgo',
  }
  ~>
  exec { 'zsbl-reset-config':
    command     => '/bin/rm -f /usr/src/zsbl/.config',
    refreshonly => true,
  }

  exec { 'zsbl-defconfig':
    command => "/usr/bin/make ${nest::soc}_defconfig",
    cwd     => '/usr/src/zsbl',
    creates => '/usr/src/zsbl/.config',
    require => Exec['zsbl-reset-config'],
    notify  => Exec['zsbl-build'],
  }

  # Build without distcc for the special toolchain, disable SSP,
  # and disable warnings-as-errors for newlib/GCC 13 compatibility
  $zsbl_make_cmd = @("ZSBL_MAKE")
    #!/bin/bash
    set -ex -o pipefail
    export HOME=/root PATH=/usr/bin:/bin
    cd /usr/src/zsbl
    make ${nest::base::portage::makeopts} KCFLAGS='-U_FORTIFY_SOURCE -Wno-error' 2>&1 | tee build.log
    | ZSBL_MAKE

  file { '/usr/src/zsbl/build.sh':
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => $zsbl_make_cmd,
  }

  exec { 'zsbl-olddefconfig':
    command     => '/usr/bin/make olddefconfig',
    cwd         => '/usr/src/zsbl',
    refreshonly => true,
  }
  ~>
  exec { 'zsbl-build':
    command     => '/usr/src/zsbl/build.sh',
    noop        => !$facts['build'],
    refreshonly => true,
    timeout     => 0,
    require     => File['/usr/src/zsbl/build.sh'],
  }

  Exec['zsbl-defconfig']
  -> Nest::Lib::Kconfig <| config == '/usr/src/zsbl/.config' |>
  ~> Exec['zsbl-olddefconfig']
}
