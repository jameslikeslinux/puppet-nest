class nest::service::streamux (
  String $ssid,
  Sensitive $password,
) {
  #
  # Firewall
  #
  firewalld_zone { 'streamux':
    ensure     => present,
    target     => '%%REJECT%%',
    interfaces => 'wlan0',
  }

  Firewalld_service {
    zone => 'streamux',
  }

  #
  # Hostapd
  #
  package { 'net-wireless/hostapd':
    ensure => installed,
  }
  ->
  file { '/etc/hostapd/hostapd.conf':
    mode    => '0600',
    owner   => 'root',
    group   => 'root',
    content => epp('nest/streamux/hostapd.conf.epp'),
  }
  ~>
  service { 'hostapd':
    enable => true,
  }

  #
  # Dnsmasq
  #
  include nest::service::dnsmasq

  $dnsmasq_conf = @(DNSMASQ)
    interface=wlan0
    bind-interfaces
    dhcp-range=172.22.100.100,172.22.100.100,infinite
    | DNSMASQ

  file { '/etc/dnsmasq.d/streamux.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $dnsmasq_conf,
    notify  => Service['dnsmasq'],
  }

  firewalld_service { 'dhcp':
    ensure => present,
  }
}
