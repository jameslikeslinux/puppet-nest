class nest::base::network {
  file { '/etc/systemd/network':
    ensure       => directory,
    mode         => '0644',
    owner        => root,
    group        => root,
    purge        => true,
    recurse      => true,
    source       => [
      'puppet:///modules/nest/private/network',
      'puppet:///modules/nest/network',
    ],
    sourceselect => all,
  }
  ~>
  exec { 'systemd-networkd-reload':
    command     => '/bin/networkctl reload',
    onlyif      => '/bin/systemctl is-active systemd-networkd',
    refreshonly => true,
  }
  ->
  service { 'systemd-networkd':
    enable => true,
  }


  if $::nest::wifi {
    package { 'net-wireless/iwd':
      ensure => installed,
    }
    ->
    file { '/var/lib/iwd':
      ensure    => directory,
      mode      => '0600',
      owner     => root,
      group     => root,
      recurse   => true,
      show_diff => false,
      source    => 'puppet:///modules/nest/private/iwd',
    }
    ->
    service { 'iwd':
      enable => true,
    }
  } else {
    service { 'iwd':
      ensure => stopped,
      enable => false,
    }
    ->
    package { 'net-wireless/iwd':
      ensure => absent,
    }
    ->
    file { '/var/lib/iwd':
      ensure => absent,
      force  => true,
    }
  }



  #
  # XXX: Deprecated
  #
  package { 'net-misc/networkmanager':
    ensure => installed,
  }

  $networkmanager_conf = @(EOT)
    [connection]
    ipv6.ip6-privacy=2
    wifi.powersave=2

    [keyfile]
    unmanaged-devices=interface-name:cni-podman*,interface-name:tun*,interface-name:veth*,interface-name:virbr*,interface-name:vnet*
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
    enable  => false,
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
