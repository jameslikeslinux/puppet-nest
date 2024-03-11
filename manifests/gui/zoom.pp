class nest::gui::zoom {
  if $facts['profile']['architecture'] == 'amd64' {
    nest::lib::package { 'net-im/zoom':
      ensure => installed,
      use    => ['bundled-libjpeg-turbo'],
    }
  }
}
