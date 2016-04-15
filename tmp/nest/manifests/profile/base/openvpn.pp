class nest::profile::base::openvpn {
  $device     = 'tun0'
  $hosts_file = '/etc/hosts.nest'

  $server_config = @("EOT")
    dev ${device}
    server 172.22.2.0 255.255.255.0
    topology subnet
    client-to-client
    keepalive 10 60
    push "dhcp-option DOMAIN nest"
    push "dhcp-option DNS 172.22.2.1"
    script-security 2
    setenv HOSTS ${hosts_file}
    learn-address /etc/openvpn/learn-address.sh
    ifconfig-pool-persist nest-ipp.txt
    dh /etc/openvpn/dh4096.pem
    | EOT

  $client_config = @(EOT)
    dev tun
    client
    nobind
    remote nest.james.tl 1194
    script-security 2
    up /etc/openvpn/up.sh
    down /etc/openvpn/down.sh
    down-pre
    | EOT

  $common_config = @("EOT")
    ca ${::settings::localcacert}
    cert ${::settings::hostcert}
    key ${::settings::hostprivkey}
    crl-verify ${::settings::hostcrl}
    cipher AES-128-CBC
    persist-tun
    | EOT

  $dnsmasq_config = @("EOT")
    resolv-file=/etc/resolv.conf.dnsmasq
    interface=lo
    interface=${device}
    bind-interfaces
    no-hosts
    addn-hosts=${hosts_file}
    expand-hosts
    domain=nest
    enable-dbus
    | EOT

  $dnsmasq_systemd_dropin_unit = @("EOT")
    [Unit]
    Requires=sys-subsystem-net-devices-${device}.device
    After=sys-subsystem-net-devices-${device}.device
    | EOT

  File {
    owner => 'root',
    group => 'root',
  }

  if $::nest::server {
    $mode        = 'server'
    $mode_config = $server_config

    exec { 'openvpn-create-dh-parameters':
      command => '/usr/bin/openssl dhparam -out /etc/openvpn/dh4096.pem 4096',
      creates => '/etc/openvpn/dh4096.pem',
      timeout => 0,
      require => Package['net-misc/openvpn'],
      before  => Service["openvpn-${mode}@nest"],
    }

    file { '/etc/openvpn/learn-address.sh':
      mode    => '0755',
      source  => 'puppet:///modules/nest/openvpn/learn-address.sh',
      require => Package['net-misc/openvpn'],
      before  => Service["openvpn-${mode}@nest"],
    }

    file { $hosts_file:
      ensure => file,
      mode   => '0644',
    }

    host { $::trusted['certname']:
      ip      => '172.22.2.1',
      target  => $hosts_file,
      require => File[$hosts_file],
      notify  => Service['dnsmasq'],
    }

    package { 'net-dns/dnsmasq':
      ensure => installed,
    }

    file_line { 'dnsmasq.conf-conf-dir':
      path    => '/etc/dnsmasq.conf',
      line    => 'conf-dir=/etc/dnsmasq.d/,*.conf',
      match   => '^#conf-dir=/etc/dnsmasq.d/,\*.conf',
      require => Package['net-dns/dnsmasq'],
    }

    file { '/etc/dnsmasq.d':
      ensure  => directory,
      mode    => '0755',
      require => File_line['dnsmasq.conf-conf-dir'],
    }

    file { '/etc/dnsmasq.d/nest.conf':
      mode    => '0644',
      content => $dnsmasq_config,
      notify  => Service['dnsmasq'],
    }
  
    $dnsmasq_cnames = $::nest::cnames.map |$alias, $cname| { "cname=${alias}.nest,${cname}.nest" }
    $dnsmask_cnames_content = $dnsmasq_cnames.join("\n")
    file { '/etc/dnsmasq.d/cnames.conf':
      mode    => '0644',
      content => "${dnsmask_cnames_content}\n",
      notify  => Service['dnsmasq'],
    }

    file { '/etc/systemd/system/dnsmasq.service.d':
      ensure  => directory,
      mode    => '0755',
    }

    file { '/etc/systemd/system/dnsmasq.service.d/10-openvpn.conf':
      mode    => '0644',
      content => $dnsmasq_systemd_dropin_unit,
    }

    exec { 'dnsmasq-systemd-daemon-reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      subscribe   => File['/etc/systemd/system/dnsmasq.service.d/10-openvpn.conf'],
    }

    service { 'dnsmasq':
      enable  => true,
      require => [
        Exec['dnsmasq-systemd-daemon-reload'],
        Service["openvpn-${mode}@nest"],
      ],
    }

    file_line {
      default:
        path => '/etc/resolvconf.conf';

      'resolvconf.conf-name_servers':
        line  => 'name_servers=127.0.0.1',
        match => '^#?name_servers=';

      'resolvconf.conf-search_domains':
        line => 'search_domains=nest';

      'resolvconf.conf-dnsmasq_conf':
        line => 'dnsmasq_conf=/etc/dnsmasq.d/resolv.conf';

      'resolvconf.conf-dnsmasq_resolv':
        line => 'dnsmasq_resolv=/etc/resolv.conf.dnsmasq';
    }
  } else {
    $mode        = 'client'
    $mode_config = $client_config
  }

  package { 'net-misc/openvpn':
    ensure => installed,
  }

  file { "/etc/openvpn/${mode}":
    ensure  => directory,
    mode    => '0755',
    require => Package['net-misc/openvpn'],
  }

  file { "/etc/openvpn/${mode}/nest.conf":
    mode    => '0644',
    content => "${mode_config}${common_config}",
  }

  service { "openvpn-${mode}@nest":
    enable    => true,
    subscribe => File["/etc/openvpn/${mode}/nest.conf"],
  }
}
