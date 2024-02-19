class nest::gui::virtualization {
  package { 'app-emulation/virt-manager':
    ensure => installed,
  }

  package { 'app-emulation/virt-viewer':
    ensure  => installed,
    require => Class['nest::base::zfs'],
  }
}
