class nest::role::workstation::virtualization {
  package { [
    'app-emulation/virt-manager',
    'app-emulation/virt-viewer',
  ]:
    ensure => installed,
  }
}

