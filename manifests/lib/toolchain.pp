define nest::lib::toolchain (
  Enum['present', 'absent'] $ensure   = present,
  Boolean                   $gcc_only = false,
) {
  case $ensure {
    'present': {
      include 'nest::lib::crossdev'

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
        "/etc/portage/profile/package.use.force/cross-${name}",
      ]:
        ensure => present,
      }

      if $gcc_only {
        file { "/etc/portage/profile/package.use.mask/cross-${name}":
          ensure => present,
        }
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
