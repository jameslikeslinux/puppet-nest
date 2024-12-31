class nest::firmware::zsbl {
  # Install bare-metal toolchain with newlib C library
  # - set 'libdir' to workaround https://bugs.gentoo.org/908455
  # - set TOOLCHAIN_LIBPATH for toolchain.eclass due to modified libdir
  # - disable multilib so newlib doesn't fail trying to build for rv32
  # - with /usr/bin/ld for PIE support
  nest::lib::toolchain { 'riscv64-unknown-elf':
    env      => { 'TOOLCHAIN_LIBPATH' => '/usr/lib64/gcc/riscv64-unknown-elf/14' },
    gcc_conf => '--libdir=/usr/lib64 --disable-multilib --with-ld=/usr/bin/ld',
    before   => Nest::Lib::Build['zsbl'],
  }

  nest::lib::src_repo { '/usr/src/zsbl':
    url => 'https://gitlab.james.tl/nest/forks/zsbl.git',
    ref => 'sophgo-nest',
  }
  ~>
  nest::lib::build { 'zsbl':
    defconfig => "${nest::soc}_defconfig",
    dir       => '/usr/src/zsbl',
    distcc    => false,
  }
}
