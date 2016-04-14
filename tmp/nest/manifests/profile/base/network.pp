class nest::profile::base::network {
  class use {
    package_use { 'net-misc/networkmanager':
      use => 'resolvconf',
    }
  }

  include '::nest::profile::base::network::use'

  package { 'net-misc/networkmanager':
    ensure  => installed,
    require => Package_use['net-misc/networkmanager'],
  }

  service { 'NetworkManager':
    enable  => true,
    require => Package['net-misc/networkmanager'],
  }
}
