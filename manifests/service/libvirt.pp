class nest::service::libvirt {
  include 'nest'

  $use = $facts['build'] ? {
    'stage1' => ['firewalld'],
    default  => ['firewalld', 'zfs'],
  }

  nest::lib::package { 'app-emulation/libvirt':
    ensure => installed,
    use    => $use,
  }

  if $facts['profile']['variant'] in ['mobile', 'workstation'] {
    nest::lib::package { 'app-emulation/virt-manager':
      ensure => installed,
    }
  }

  file { '/etc/libvirt/libvirt-guests.conf':
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    require => Nest::Lib::Package['app-emulation/libvirt'],
  }

  file_line { 'libvirt-guests-on_shutdown':
    path    => '/etc/libvirt/libvirt-guests.conf',
    line    => 'ON_SHUTDOWN=shutdown',
    match   => '^#?ON_SHUTDOWN=',
    require => File['/etc/libvirt/libvirt-guests.conf'],
    before  => Service['libvirt-guests'],
  }

  service { [
    'libvirtd',
    'libvirt-guests',
  ]:
    enable  => true,
    require => Nest::Lib::Package['app-emulation/libvirt'],
  }

  if $nest::fileserver or $nest::router {
    file { '/etc/systemd/system/libvirt-guests.service.d':
      ensure => directory,
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
    }
  }

  $after_fs_servers_ensure = $nest::fileserver ? {
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
    notify  => Nest::Lib::Systemd_reload['libvirt'],
  }

  if $nest::router {
    $after_openvpn_ensure = 'present'
  } else {
    $after_openvpn_ensure = 'absent'
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
    notify  => Nest::Lib::Systemd_reload['libvirt'],
  }

  nest::lib::systemd_reload { 'libvirt': }

  exec { 'prioritize-libvirt-firewalld-zone':
    command => '/usr/bin/firewall-offline-cmd --zone=libvirt --set-priority=-10',
    unless  => '/usr/bin/firewall-offline-cmd --zone=libvirt --get-priority | /usr/bin/grep -q -E -- -10',
    notify  => Class['firewalld::reload'],
    require => Package['app-emulation/libvirt'],
  }
  ->
  firewalld_zone { 'libvirt':
    # libvirt owns bridge membership, including runtime assignments restored
    # after firewalld reloads. Do not reconcile those interfaces to an empty list.
    interfaces       => undef,
    purge_rich_rules => true,
    purge_services   => true,
    purge_ports      => true,
  }

  # Preserve libvirt's host-input boundary without changing its forwarding
  # target. TFTP is not enabled in Nest's dnsmasq builds; do not introduce the
  # packaged TFTP helper merely to serve DHCP/DNS on NAT networks.
  ['dhcp', 'dhcpv6', 'dns', 'ssh'].each |$service| {
    firewalld_service { "libvirt-${service}":
      ensure  => present,
      service => $service,
      zone    => 'libvirt',
      require => Firewalld_rich_rule['libvirt-reject-other-host-input'],
    }
  }

  firewalld_rich_rule { 'libvirt-reject-other-host-input':
    ensure   => present,
    zone     => 'libvirt',
    raw_rule => 'rule priority="32767" reject',
  }

  if $nest::fileserver {
    firewalld_service { ['nfs', 'samba']:
      ensure => present,
      zone   => 'libvirt',
    }
  }
}
