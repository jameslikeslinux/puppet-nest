class nest::base::network {
  package { 'net-misc/networkmanager':
    ensure => installed,
  }

  $networkmanager_conf = @(EOT)
    [connection]
    ipv6.ip6-privacy=2
    wifi.powersave=2

    [keyfile]
    unmanaged-devices=interface-name:cni-podman*,interface-name:tun0,interface-name:virbr*,interface-name:vnet*
    | EOT

  file {
    default:
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      require => Package['net-misc/networkmanager'],
      notify  => Service['NetworkManager'],
    ;

    '/etc/NetworkManager/NetworkManager.conf':
      content => $networkmanager_conf,
    ;

    '/etc/NetworkManager/conf.d/10-powersave.conf':
      ensure => absent,
    ;
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
