class nest::profile::base::dnsmasq {
  package { 'net-dns/dnsmasq':
    ensure => installed,
  }

  File_line {
    path    => '/etc/dnsmasq.conf',
    require => Package['net-dns/dnsmasq'],
    notify  => Service['dnsmasq'],
  }

  file_line { 'dnsmasq.conf-domain-needed':
    line  => 'domain-needed',
    match => '^#?domain-needed$'
  }

  file_line { 'dnsmasq.conf-resolv-file':
    line  => 'resolv-file=/etc/dnsmasq-resolv.conf',
    match => '^#?resolv-file=',
  }

  file_line { 'dnsmasq.conf-conf-file':
    line  => 'conf-file=/etc/dnsmasq-conf.conf',
    after => '^#?resolv-file=',
  }

  file_line { 'dnsmasq.conf-enable-dbus':
    line => 'enable-dbus',
  }

  file_line { 'dnsmasq.conf-no-hosts':
    line  => 'no-hosts',
    match => '^#?no-hosts$',
  }

  file_line { 'dnsmasq.conf-addn-hosts':
    line  => 'addn-hosts=/etc/hosts.openvpn-clients',
    match => '^#?addn-hosts=',
  }

  file_line { 'dnsmasq.conf-bind-interfaces':
    line  => 'bind-interfaces',
    match => '^#?bind-interface$',
  }

  file_line { 'dnsmasq.conf-interface-lo':
    line  => 'interface=lo',
    match => '^#?interface=',
  }

  file_line { 'dnsmasq.conf-interface-tun0':
    line    => 'interface=tun0',
    after   => '^interface=lo$',
    require => File_line['dnsmasq.conf-interface-lo'],
  }

  service { 'dnsmasq':
    enable => true,
  }
}
