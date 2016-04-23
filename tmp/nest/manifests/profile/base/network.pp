class nest::profile::base::network {
  nest::portage::package_use { 'net-misc/networkmanager':
    use => 'resolvconf',
  }

  package { 'net-misc/networkmanager':
    ensure  => installed,
    require => Package_use['net-misc/networkmanager'],
  }

  service { 'NetworkManager':
    enable  => true,
    require => Package['net-misc/networkmanager'],
  }
}
