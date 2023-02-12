class nest::service::streamux (
  String $ssid,
  Sensitive $password,
) {
  #
  # Hostapd
  #
  nest::lib::package { 'net-wireless/hostapd':
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

  file { '/etc/dnsmasq.d/streamux.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "interface=wlan0\ndhcp-range=172.22.100.100,172.22.100.100,infinite\n",
    notify  => Service['dnsmasq'],
  }
}
