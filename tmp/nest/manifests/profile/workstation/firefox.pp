class nest::profile::workstation::firefox {
  class use {
    package_use { 'www-client/firefox':
      use => 'gtk3',
    }
  }

  include '::nest::profile::workstation::firefox::use'

  package { 'www-client/firefox':
    ensure => installed,
  }
}
