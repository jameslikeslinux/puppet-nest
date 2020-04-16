class nest::role::workstation::libvirt {
  $virt_manager_ensure = $::nest::libvirt ? {
    true    => 'installed',
    default => 'absent',
  }

  package { [
    'app-emulation/virt-manager',
    'app-emulation/virt-viewer',
  ]:
    ensure => $virt_manager_ensure,
  }
}
