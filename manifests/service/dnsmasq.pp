class nest::service::dnsmasq (
  Array[String] $interfaces = [],
) {
  File {
    mode  => '0644',
    owner => 'root',
    group => 'root',
  }

  package { 'net-dns/dnsmasq':
    ensure => installed,
  }
  ->
  file_line { 'dnsmasq.conf-conf-dir':
    path  => '/etc/dnsmasq.conf',
    line  => 'conf-dir=/etc/dnsmasq.d/,*.conf',
    match => '^#?conf-dir=/etc/dnsmasq.d/,\*.conf',
  }
  ->
  file { '/etc/dnsmasq.d':
    ensure  => directory,
    require => File_line['dnsmasq.conf-conf-dir'],
  }
  ->
  service { 'dnsmasq':
    enable => true,
  }

  if $interfaces.empty {
    file { '/etc/dnsmasq.d/interfaces.conf':
      ensure => absent,
      notify => Service['dnsmasq'],
    }
  } else {
    $dnsmasq_interfaces = $interfaces.map |$i| { "interface=${i}" }.join("\n")
    $dnsmasq_interfaces_conf = @("END_CONF")
      ${dnsmasq_interfaces}
      bind-dynamic
      | END_CONF

    file { '/etc/dnsmasq.d/interfaces.conf':
      content => $dnsmasq_interfaces_conf,
      notify  => Service['dnsmasq'],
    }
  }
}
