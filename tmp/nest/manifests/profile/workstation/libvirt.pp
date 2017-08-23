class nest::profile::workstation::libvirt {
  $virt_manager_ensure = $::nest::libvirt ? {
    true    => 'installed',
    default => 'absent',
  }

  package { 'app-emulation/virt-manager':
    ensure => $virt_manager_ensure,
  }
}
