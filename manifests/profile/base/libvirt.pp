class nest::profile::base::libvirt {
  nest::portage::package_use { 'app-emulation/libvirt':
    use => ['virt-network', 'zfs'],
  }

  package { 'app-emulation/libvirt':
    ensure => installed,
  }

  file { '/etc/libvirt/libvirt-guests.conf':
    ensure  => present,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    require => Package['app-emulation/libvirt'],
  }

  file_line { 'libvirt-guests-on_shutdown':
    path    => '/etc/libvirt/libvirt-guests.conf',
    line    => 'ON_SHUTDOWN=shutdown',
    match   => '^#?ON_SHUTDOWN=',
    require => File['/etc/libvirt/libvirt-guests.conf'],
    before  => Service['libvirt-guests'],
  }

  # Ensure libvirt can find the UEFI firmware
  file_line { 'libvirt-qemu-nvram':
    path    => '/etc/libvirt/qemu.conf',
    line    => 'nvram = ["/usr/share/edk2-ovmf/OVMF_CODE.fd:/usr/share/edk2-ovmf/OVMF_VARS.fd"]',
    match   => '^#?nvram = \[',
    require => Package['app-emulation/libvirt'],
    notify  => Service['libvirtd'],
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

  # Do not filter bridge packets
  # See: https://wiki.libvirt.org/page/Net.bridge.bridge-nf-call_and_sysctl.conf
  sysctl { [
    'net.bridge.bridge-nf-call-arptables',
    'net.bridge.bridge-nf-call-ip6tables',
    'net.bridge.bridge-nf-call-iptables',
  ]:
    value  => '0',
    target => '/etc/sysctl.d/bridge.conf',
  }

  $bridge_udev_rules = @(EOT)
    ACTION=="add", SUBSYSTEM=="module", KERNEL=="bridge", RUN+="/lib/systemd/systemd-sysctl --prefix=/proc/sys/net/bridge"
    | EOT

  # Apply the parameters from above when the bridge module is loaded
  # See sysctl.d(5)
  file { '/etc/udev/rules.d/99-bridge.rules':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $bridge_udev_rules,
  }
}
