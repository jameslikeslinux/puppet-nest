class nest::profile::base::network {
  # resolvconf now provided by systemd
  nest::lib::portage::package_use { 'net-misc/networkmanager':
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
    unmanaged-devices=interface-name:docker*,interface-name:tun0,interface-name:virbr*,interface-name:vnet*
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

  # "mask" service which potentially holds up the boot process when on wireless
  $wait_online_ensure = $facts['interfaces'] ? {
    #/(^|,)wl/ => symlink,
    default   => absent,
  }

  file { '/etc/systemd/system/NetworkManager-wait-online.service':
    ensure => $wait_online_ensure,
    target => '/dev/null',
    notify => Nest::Lib::Systemd_reload['NetworkManager'],
  }

  # probably not *strictly* necessary, but good practice none-the-less
  ::nest::lib::systemd_reload { 'NetworkManager': }
}
