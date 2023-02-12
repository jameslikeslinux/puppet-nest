class nest::service::dnsmasq {
  package { 'net-dns/dnsmasq':
    ensure => installed,
  }
  ->
  file_line { 'dnsmasq.conf-conf-dir':
    path    => '/etc/dnsmasq.conf',
    line    => 'conf-dir=/etc/dnsmasq.d/,*.conf',
    match   => '^#?conf-dir=/etc/dnsmasq.d/,\*.conf',
  }
  ->
  file { '/etc/dnsmasq.d':
    ensure  => directory,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    require => File_line['dnsmasq.conf-conf-dir'],
  }
  ->
  service { 'dnsmasq':
    enable => true,
  }
}
