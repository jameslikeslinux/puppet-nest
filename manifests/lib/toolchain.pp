define nest::lib::toolchain (
  Enum['present', 'absent'] $ensure = present,
) {
  case $ensure {
    'present': {
      include 'nest::lib::crossdev'

      exec { "crossdev-install-${name}":
        command => "/usr/bin/crossdev --stable --target ${name}",
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
