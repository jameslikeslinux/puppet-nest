class nest::role::workstation::zoom {
  if $facts['architecture'] in ['amd64', 'x86_64'] {
    nest::lib::package_use { 'net-im/zoom':
      use => ['bundled-libjpeg-turbo'],
    }

    package { 'net-im/zoom':
      ensure => installed,
    }
  }
}
