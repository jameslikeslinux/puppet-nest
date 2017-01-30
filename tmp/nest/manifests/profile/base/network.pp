class nest::profile::base::network {
  nest::portage::package_use { 'net-misc/networkmanager':
    use => 'resolvconf',
  }

  package { 'net-misc/networkmanager':
    ensure  => installed,
    require => Package_use['net-misc/networkmanager'],
  }

  $networkmanager_conf = @(EOT)
    [connection]
    ipv6.ip6-privacy=2
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

  # Probably not *strictly* necessary, but good practice none-the-less
  exec { 'NetworkManager-systemd-daemon-reload':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  # Work-around terrible SB6190 (https://www.dslreports.com/forum/r31122204-SB6190-Puma6-TCP-UDP-Network-Latency-Issue-Discussion)
  # Use TCP for DNS resolution
  file_line { 'resolvconf.conf-resolv_conf_options':
    path    => '/etc/resolvconf.conf',
    line    => 'resolv_conf_options=use-vc',
    match   => '^#?resolv_conf_options=.*',
    require => Package['net-misc/networkmanager'],
    notify  => Service['NetworkManager'],
  }
}
