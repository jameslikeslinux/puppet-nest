class nest::profile::base::network {
  # resolvconf now provided by systemd
  nest::portage::package_use { 'net-misc/networkmanager':
    ensure => absent,
    use    => 'resolvconf',
  }

  package { 'net-misc/networkmanager':
    ensure  => installed,
    require => Package_use['net-misc/networkmanager'],
  }

  $networkmanager_conf = @(EOT)
    [connection]
    ipv6.ip6-privacy=2

    [keyfile]
    unmanaged-devices=interface-name:tun0
    | EOT

  file { '/etc/NetworkManager/NetworkManager.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $networkmanager_conf,
    require => Package['net-misc/networkmanager'],
    notify  => Service['NetworkManager'],
  }

  service { 'NetworkManager':
    enable  => true,
    require => Package['net-misc/networkmanager'],
  }

  # "mask" service which holds up the boot process
  file { '/etc/systemd/system/NetworkManager-wait-online.service':
    ensure => symlink,
    target => '/dev/null',
    notify => Exec['NetworkManager-systemd-daemon-reload'],
  }

  # probably not *strictly* necessary, but good practice none-the-less
  exec { 'NetworkManager-systemd-daemon-reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
  }
}
