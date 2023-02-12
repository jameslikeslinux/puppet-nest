class nest::service::libvirt {
  include 'nest'

  nest::lib::package_use { 'app-emulation/libvirt':
    use => 'firewalld',
  }

  package { 'app-emulation/libvirt':
    ensure => installed,
  }

  # libvirt pulls in LVM so we have to manage it
  file_line { 'lvm.conf-global_filter-zvol':
    path    => '/etc/lvm/lvm.conf',
    line    => "\tglobal_filter = [ \"r|/dev/zd.*|\" ]",
    match   => 'global_filter = ',
    require => Package['app-emulation/libvirt'],
  }

  file { '/etc/libvirt/libvirt-guests.conf':
    ensure  => file,
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

  service { [
    'libvirtd',
    'libvirt-guests',
  ]:
    enable  => true,
    require => Package['app-emulation/libvirt'],
  }

  if $nest::fileserver or $nest::openvpn_server {
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

  $after_openvpn_ensure = $nest::openvpn_server ? {
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
    notify  => Nest::Lib::Systemd_reload['libvirt'],
  }

  ::nest::lib::systemd_reload { 'libvirt': }

  firewalld_zone { 'libvirt':
    purge_rich_rules => true,
    purge_services   => true,
    purge_ports      => true,
    require          => Package['app-emulation/libvirt'],
  }

  if $nest::fileserver {
    firewalld_service { ['nfs', 'samba']:
      ensure => present,
      zone   => 'libvirt',
    }
  }

  # Install and use Vagrant libvirt provider as a container
  file { '/usr/local/bin/vagrant':
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/nest/scripts/vagrant.sh',
  }
}
