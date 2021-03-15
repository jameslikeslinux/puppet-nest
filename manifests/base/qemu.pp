class nest::base::qemu {
  case $facts['osfamily'] {
    'Gentoo': {
      if $facts['virtual'] == 'kvm' or $::nest::live {
        $qemu_guest_agent_ensure = installed
      } else {
        $qemu_guest_agent_ensure = absent
      }

      package { 'app-emulation/qemu-guest-agent':
        ensure => $qemu_guest_agent_ensure,
      }
    }

    'windows': {
      package { 'virtio-drivers':
        ensure => installed,
      }
    }
  }
}
