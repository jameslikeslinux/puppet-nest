class nest::lib::router {
  $dnsmasq_config = @("EOT")
    resolv-file=/run/systemd/resolve/resolv.conf
    no-hosts
    addn-hosts=/etc/hosts.nest
    expand-hosts
    domain=nest
    dhcp-range=172.22.4.100,172.22.4.254
    dhcp-option=option:router,172.22.4.1
    dhcp-option=option:classless-static-route,0.0.0.0/0,172.22.4.1,172.22.0.0/24,172.22.4.2
    | EOT

  file { '/etc/hosts.nest':
    ensure => file,
    mode   => '0644',
  }

  class { 'nest::service::dnsmasq':
    interfaces      => ['tun0', 'br0'],
    bind_interfaces => true,
  }

  file { '/etc/dnsmasq.d/nest.conf':
    mode    => '0644',
    content => $dnsmasq_config,
    notify  => Service['dnsmasq'],
  }

  file {
    default:
      mode   => '0644',
      notify => Service['dnsmasq'],
    ;

    '/etc/dnsmasq.d/cnames.conf':
      content => $nest::cnames.map |$alias, $cname| { "cname=${alias},${cname}\n" }.join(''),
    ;

    '/etc/dnsmasq.d/dhcp-hosts.conf':
      content => $nest::fixed_ips.map |$name, $ip| { "dhcp-host=${name},${ip}\n" }.join(''),
    ;

    '/etc/dnsmasq.d/host-records.conf':
      content => $nest::host_records.map |$name, $ip| { "host-record=${name},${ip}\n" }.join(''),
    ;
  }

  firewalld_service { 'dhcp':
    ensure => present,
    zone   => 'external',
  }
}
