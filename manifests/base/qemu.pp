class nest::base::qemu {
  if $facts['virtual'] == 'kvm'
  or $facts['profile']['platform'] == 'live'
  or ($facts['dmi'] and $facts['dmi']['manufacturer'] and $facts['dmi']['manufacturer'] =~ /OVMF/) {
    $qemu_guest_agent_ensure = installed
  } else {
    $qemu_guest_agent_ensure = absent
  }

  $package_name = $facts['os']['family'] ? {
    'Gentoo'  => 'app-emulation/qemu-guest-agent',
    'windows' => 'virtio-drivers',
    default   => undef,
  }

  if $package_name {
    package { $package_name:
      ensure => $qemu_guest_agent_ensure,
    }
  }
}
