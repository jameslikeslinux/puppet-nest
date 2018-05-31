class nest::profile::base::openvpn {
  $device     = 'tun0'
  $hosts_file = '/etc/hosts.nest'

  $server_config = @("EOT")
    dh /etc/openvpn/dh4096.pem
    server 172.22.0.0 255.255.255.0
    topology subnet
    client-to-client
    keepalive 10 30
    push "dhcp-option DOMAIN nest"
    push "dhcp-option DNS 172.22.0.1"
    push "route 172.22.2.0 255.255.255.0"
    script-security 2
    setenv HOSTS ${hosts_file}
    learn-address /etc/openvpn/learn-address.sh
    ifconfig-pool-persist nest-ipp.txt
    | EOT

  $client_config = @("EOT")
    client
    nobind
    remote ${::nest::openvpn_hostname} 1194
    script-security 2
    up /etc/openvpn/up.sh
    down /etc/openvpn/down.sh
    down-pre
    | EOT

  $common_config = @("EOT")
    dev ${device}
    persist-tun
    txqueuelen 1000
    cipher AES-128-CBC
    ca ${::settings::localcacert}
    cert ${::settings::certdir}/${::trusted['certname']}.pem
    key ${::settings::privatekeydir}/${::trusted['certname']}.pem
    crl-verify ${::settings::hostcrl}
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

  if $::nest::openvpn_server {
    $mode        = 'server'
    $mode_config = $server_config

    exec { 'openvpn-create-dh-parameters':
      command => '/usr/bin/openssl dhparam -out /etc/openvpn/dh4096.pem 4096',
      creates => '/etc/openvpn/dh4096.pem',
      timeout => 0,
      require => Package['net-vpn/openvpn'],
      before  => Service["openvpn-${mode}@nest"],
    }

    file { '/etc/openvpn/learn-address.sh':
      mode    => '0755',
      source  => 'puppet:///modules/nest/openvpn/learn-address.sh',
      require => Package['net-vpn/openvpn'],
      before  => Service["openvpn-${mode}@nest"],
    }

    file { $hosts_file:
      ensure => file,
      mode   => '0644',
    }

    host { $::trusted['certname']:
      ip      => '172.22.0.1',
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
      match   => '^#?conf-dir=/etc/dnsmasq.d/,\*.conf',
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

    $dnsmasq_cnames = $::nest::cnames.map |$alias, $cname| { "cname=${alias},${cname}" }
    $dnsmasq_cnames_content = $dnsmasq_cnames.join("\n")
    $dnsmasq_cnames_ensure = $dnsmasq_cnames_content ? {
      ''      => 'absent',
      default => 'present',
    }

    file { '/etc/dnsmasq.d/cnames.conf':
      ensure  => $dnsmasq_cnames_ensure,
      mode    => '0644',
      content => "${dnsmasq_cnames_content}\n",
      notify  => Service['dnsmasq'],
    }

    file { '/etc/systemd/system/dnsmasq.service.d':
      ensure => directory,
      mode   => '0755',
    }

    file { '/etc/systemd/system/dnsmasq.service.d/10-openvpn.conf':
      mode    => '0644',
      content => $dnsmasq_systemd_dropin_unit,
    }

    exec { 'dnsmasq-systemd-daemon-reload':
      command     => '/bin/systemctl daemon-reload',
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

    firewall { '100 openvpn':
      proto  => udp,
      dport  => 1194,
      state  => 'NEW',
      action => accept,
    }

    firewall { '100 openvpn (v6)':
      proto    => udp,
      dport    => 1194,
      state    => 'NEW',
      action   => accept,
      provider => ip6tables,
    }

    firewall { '100 block connections into nest VPN':
      chain    => 'FORWARD',
      proto    => all,
      outiface => $device,
      state    => ['RELATED', 'ESTABLISHED'],
      action   => accept,
    }

    firewall { '101 block connections into nest VPN':
      chain    => 'FORWARD',
      proto    => all,
      outiface => $device,
      action   => drop,
    }
  } else {
    $mode        = 'client'
    $mode_config = $client_config
  }

  package { 'net-vpn/openvpn':
    ensure => installed,
  }

  file { "/etc/openvpn/${mode}":
    ensure  => directory,
    mode    => '0755',
    require => Package['net-vpn/openvpn'],
  }

  file { "/etc/openvpn/${mode}/nest.conf":
    mode    => '0644',
    content => "${common_config}${mode_config}",
  }

  service { "openvpn-${mode}@nest":
    enable    => true,
    subscribe => File["/etc/openvpn/${mode}/nest.conf"],
  }

  firewall { '001 vpn':
    proto   => all,
    iniface => $device,
    action  => accept,
  }
}
