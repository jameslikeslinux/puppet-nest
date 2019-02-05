class nest::profile::base::qemu {
  if $::nest::qemu_ga_enabe {
    package { 'app-emulation/qemu-guest-agent':
      ensure => installed,
    }

    service { 'qemu-guest-agent':
      enable  => true,
      require => Package['app-emulation/qemu-guest-agent'],
    }
  } else {
    service { 'qemu-guest-agent':
      enable => false,
    }

    package { 'app-emulation/qemu-guest-agent':
      ensure  => absent,
      require => Service['qemu-guest-agent'],
    }
  }
}
