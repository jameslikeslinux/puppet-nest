class nest::profile::base::qemu {
  $qemu_guest_agent_ensure = $::nest::vm ? {
    true    => installed,
    default => absent,
  }

  package { 'app-emulation/qemu-guest-agent':
    ensure => $qemu_guest_agent_ensure,
  }
}
