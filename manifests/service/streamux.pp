class nest::service::streamux (
  String $ssid,
  Sensitive $password,
) {
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

  nest::lib::package { 'net-dns/dnsmasq':
    ensure => installed,
  }
  ->
  file { '/etc/dnsmasq.d/streamux.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "interface=wlan0\ndhcp-range=172.22.100.100,172.22.100.100,infinite\n",
  }
  ~>
  service { 'dnsmasq':
    enable => true,
  }
}
