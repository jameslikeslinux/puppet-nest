class nest::profile::base::libvirt {
  package_use { 'app-emulation/libvirt':
    use => 'virt-network',
  }

  package { 'app-emulation/libvirt':
    ensure => installed,
  }

  file_line { 'libvirt-guests-on_shutdown':
    path    => '/etc/libvirt/libvirt-guests.conf',
    line    => 'ON_SHUTDOWN=shutdown',
    match   => '^#?ON_SHUTDOWN=',
    require => Package['app-emulation/libvirt'],
    before  => Service['libvirt-guests'],
  }

  service { [
    'libvirtd',
    'libvirt-guests',
  ]:
    enable  => true,
    require => Package['app-emulation/libvirt'],
  }
}
