class nest::service::streamux (
  String $ssid,
  Sensitive $password,
) {
  #
  # Firewall
  #
  Firewalld_zone <| title == 'external' |> {
    interfaces +> 'wlan0',
  }

  firewalld_rich_rule { 'streamux-nat':
    source     => '172.22.100.0/24',
    masquerade => true,
    zone       => 'external',
  }

  firewalld_zone { 'streamux':
    ensure  => present,
    sources => '172.22.100.0/24',
    target  => 'default',
  }

  Firewalld_port {
    zone => 'streamux',
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
    dhcp-range=172.22.100.100,172.22.100.199,1d
    | DNSMASQ

  file { '/etc/dnsmasq.d/streamux.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $dnsmasq_conf,
    notify  => Service['dnsmasq'],
  }

  firewalld_service { ['dhcp', 'dns']:
    ensure => present,
  }

  #
  # Nginx
  #
  nest::lib::package { 'www-servers/nginx':
    ensure => installed,
    use    => 'rtmp',
  }

  firewalld_port { 'rtmp':
    ensure   => present,
    port     => 1935,
    protocol => 'tcp',
  }

  #
  # ffmpeg
  #
  nest::lib::package { 'media-video/ffmpeg':
    ensure => installed,
    use    => 'x264',
  }

  #
  # Streamux
  #
  vcsrepo { '/home/james/streamux':
    ensure   => latest,
    provider => git,
    source   => 'https://gitlab.james.tl/james/streamux.git',
    revision => 'main',
    user     => 'james',
  }

  package { 'media-gfx/qrencode':
    ensure => installed,
  }
}
