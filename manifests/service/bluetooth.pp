class nest::service::bluetooth {
  if $facts['os']['family'] == 'Gentoo' {
    nest::lib::package { 'net-wireless/bluez':
      ensure => installed,
    }
    ->
    service { 'bluetooth':
      enable => true,
    }
  }
}
