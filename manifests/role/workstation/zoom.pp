class nest::role::workstation::zoom {
  if $facts['architecture'] == 'amd64' {
    nest::lib::package_use { 'net-im/zoom':
      use => ['bundled-libjpeg-turbo'],
    }

    package { 'net-im/zoom':
      ensure => installed,
    }
  }
}
