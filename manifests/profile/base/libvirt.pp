class nest::profile::base::libvirt {
  nest::portage::package_use { 'app-emulation/libvirt':
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

  if $::nest::fileserver or $::nest::openvpn_server {
    file { '/etc/systemd/system/libvirt-guests.service.d':
      ensure => directory,
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
    }
  }

  $after_fs_servers_ensure = $::nest::fileserver ? {
    true    => 'present',
    default => 'absent',
  }

  $after_fs_servers_conf = @(EOT)
    [Unit]
    After=nfs-server.service smbd.service
    | EOT

  file { '/etc/systemd/system/libvirt-guests.service.d/10-after-fs-servers.conf':
    ensure  => $after_fs_servers_ensure,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $after_fs_servers_conf,
    notify  => Exec['libvirt-systemd-daemon-reload'],
  }

  $after_openvpn_ensure = $::nest::openvpn_server ? {
    true    => 'present',
    default => 'absent',
  }

  $after_openvpn_conf = @(EOT)
    [Unit]
    After=openvpn-server@nest.service
    | EOT

  file { '/etc/systemd/system/libvirt-guests.service.d/10-after-openvpn.conf':
    ensure  => $after_openvpn_ensure,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $after_openvpn_conf,
    notify  => Exec['libvirt-systemd-daemon-reload'],
  }

  exec { 'libvirt-systemd-daemon-reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
  }
}
