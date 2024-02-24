define nest::lib::toolchain (
  Enum['present', 'absent'] $ensure   = present,
  Optional[String]          $gcc_env  = undef,
  Boolean                   $gcc_only = false,
) {
  case $ensure {
    'present': {
      include 'nest::lib::crossdev'

      if $gcc_env {
        $gcc_env_args = "--genv ${gcc_env.shellquote}"
      } else {
        $gcc_env_args = ''
      }

      if $gcc_only {
        $stage_arg = '--stage1'
      } else {
        $stage_arg = ''
      }

      exec { "crossdev-install-${name}":
        command => "/usr/bin/crossdev ${gcc_env_args} --stable --portage '--usepkg' ${stage_arg} --target ${name}",
        creates => "/usr/bin/${name}-gcc",
        timeout => 0,
        require => Class['nest::lib::crossdev'],
      }
      ->
      file {
        "/etc/portage/env/cross-${name}":
          ensure => directory,
        ;

        [
          "/etc/portage/package.accept_keywords/cross-${name}",
          "/etc/portage/package.env/cross-${name}",
          "/etc/portage/package.use/cross-${name}",
          "/etc/portage/profile/package.use.force/cross-${name}",
        ]:
          ensure => file,
        ;
      }

      # Bare-metal toolchains mask various USE flags
      if $name =~ /-(eabi|elf)$/ {
        file { "/etc/portage/profile/package.use.mask/cross-${name}":
          ensure  => file,
          require => Exec["crossdev-install-${name}"],
        }
      }

      if $facts['llvm_clang'] {
        file {
          default:
            ensure => link,
            notify => Class['nest::base::distccd'];
          "/usr/local/bin/${name}-clang":
            target => $facts['llvm_clang'];
          "/usr/local/bin/${name}-clang++":
            target => "${facts['llvm_clang']}++",
          ;
        }
      }
    }

    'absent': {
      exec { "crossdev-uninstall-${name}":
        command => "/usr/bin/crossdev -C ${name}",
        onlyif  => "/usr/bin/test -e /usr/bin/${name}-gcc",
      }

      file { [
        "/usr/local/bin/${name}-clang",
        "/usr/local/bin/${name}-clang++",
      ]:
        ensure => absent,
        notify => Class['nest::base::distccd'],
      }
    }
  }
}
