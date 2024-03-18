class nest::firmware::arm {
  if $nest::soc == 'rk3399' {
    nest::lib::toolchain { 'arm-none-eabi':
      gcc_only => true,
      before   => Nest::Lib::Build['arm-trusted-firmware']
    }
  }

  nest::lib::src_repo { '/usr/src/arm-trusted-firmware':
    url => 'https://gitlab.james.tl/nest/forks/arm-trusted-firmware.git',
    ref => 'main',
  }
  ~>
  nest::lib::build { 'arm-trusted-firmware':
    args => "E=0 PLAT=${nest::soc} LDFLAGS=-no-warn-rwx-segment", # LDFLAGS for GCC 12 workaround
    dir  => '/usr/src/arm-trusted-firmware',
  }
}
