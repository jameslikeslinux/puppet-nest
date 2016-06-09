class nest::profile::workstation::packages {
  nest::portage::package_use { 'net-im/pidgin':
    use => 'networkmanager',
  }

  package { [
    'net-im/pidgin',
    'x11-plugins/pidgin-skypeweb',
  ]:
    ensure => installed,
  }
}
