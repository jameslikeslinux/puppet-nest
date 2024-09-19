class nest::node::falcon {
  nest::lib::toolchain {
    [
      'aarch64-unknown-linux-gnu',
      'armv7a-unknown-linux-gnueabihf',
      'riscv64-unknown-linux-gnu',
    ]:
      # use defaults
    ;

    'arm-none-eabi':
      gcc_only => true,
    ;
  }

  nest::lib::package { 'app-emulation/vendor-reset':
    ensure  => installed,
    require => Class['nest::base::kernel'], # for CONFIG_FUNCTION_TRACER
    notify  => Class['nest::base::dracut'], # package installs module-load config
  }
}
