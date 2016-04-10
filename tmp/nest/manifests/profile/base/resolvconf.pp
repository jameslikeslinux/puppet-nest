class nest::profile::base::resolvconf {
  package { 'net-dns/openresolv':
    ensure => installed,
  }

  File_line {
    path    => '/etc/resolvconf.conf',
    require => Package['net-dns/openresolv'],
  }

  file_line { 'resolvconf.conf-name_servers':
    line  => 'name_servers=127.0.0.1',
    match => '^#?name_servers=',
  }

  file_line { 'resolvconf.conf-dnsmasq_conf':
    line => 'dnsmasq_conf=/etc/dnsmasq-conf.conf',
  }

  file_line { 'resolvconf.conf-dnsmasq_resolv':
    line => 'dnsmasq_resolv=/etc/dnsmasq-resolv.conf',
  }
}
