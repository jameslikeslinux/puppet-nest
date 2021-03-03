define nest::lib::toolchain (
  Enum['present', 'absent'] $ensure   = present,
  Boolean                   $gcc_only = false,
) {
  case $ensure {
    'present': {
      include 'nest::lib::crossdev'

      if $name =~ /armv7.*-gnueabihf$/ {
        file { "/etc/portage/env/cross-${name}-gcc.conf":
          mode  => '0644',
          owner => 'root',
          group => 'root',
          content => "EXTRA_ECONF='--with-float=hard --with-fpu=vfpv3-d16'\n",
        }

        package_env { "cross-${name}/gcc":
          env     => "cross-${name}-gcc.conf",
          require => File["/etc/portage/env/cross-${name}-gcc.conf"],
          before  => Exec["crossdev-install-${name}"],
        }
      }


      $stage = $gcc_only ? {
        true    => 1,
        default => 4,
      }

      exec { "crossdev-install-${name}":
        command => "/usr/bin/crossdev --stable --stage${stage} --target ${name}",
        creates => "/usr/bin/${name}-gcc",
        require => Class['nest::lib::crossdev'],
      }
      ->
      file { [
        "/etc/portage/env/cross-${name}",
        "/etc/portage/package.accept_keywords/cross-${name}",
        "/etc/portage/package.env/cross-${name}",
        "/etc/portage/package.use/cross-${name}",
      ]:
        ensure => present,
      }
    }

    'absent': {
      exec { "crossdev-uninstall-${name}":
        command => "/usr/bin/crossdev -C ${name}",
        onlyif  => "/usr/bin/test -e /usr/bin/${name}-gcc",
      }
    }
  }
}
