class nest::firmware::zsbl {
  # Install bare-metal toolchain with newlib C library
  # - set 'libdir' to workaround https://bugs.gentoo.org/908455
  # - disable multilib so newlib doesn't fail trying to build for rv32
  # - with /usr/bin/ld for PIE support
  nest::lib::toolchain { 'riscv64-unknown-elf':
    gcc_conf => '--libdir=/usr/lib64 --disable-multilib --with-ld=/usr/bin/ld',
    before   => Nest::Lib::Build['zsbl'],
  }

  nest::lib::src_repo { '/usr/src/zsbl':
    url => 'https://gitlab.james.tl/nest/forks/zsbl.git',
    ref => 'sophgo',
  }
  ~>
  nest::lib::build { 'zsbl':
    args      => 'KCFLAGS="-U_FORTIFY_SOURCE -Wno-error"',
    defconfig => "${nest::soc}_defconfig",
    dir       => '/usr/src/zsbl',
    distcc    => false,
  }
}
