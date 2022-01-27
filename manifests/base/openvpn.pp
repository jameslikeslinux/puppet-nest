class nest::base::openvpn {
  $device     = 'tun0'
  $hosts_file = '/etc/hosts.nest'

  $server_config = @("EOT")
    ncp-ciphers AES-128-GCM
    dh /etc/openvpn/dh4096.pem
    server 172.22.0.0 255.255.255.0
    topology subnet
    client-to-client
    keepalive 10 30
    dhcp-option DOMAIN nest
    dhcp-option DOMAIN gitlab.james.tl
    dhcp-option DNS 172.22.0.1
    push "dhcp-option DOMAIN nest"
    push "dhcp-option DOMAIN gitlab.james.tl"
    push "dhcp-option DNS 172.22.0.1"
    push "route-metric 30"
    push "route 172.22.1.12"
    setenv HOSTS ${hosts_file}
    learn-address /etc/openvpn/learn-address.sh
    ifconfig-pool-persist nest-ipp.txt
    | EOT

  $client_config = @("EOT")
    client
    nobind
    remote ${::nest::openvpn_hostname} 1194
    | EOT

  $common_config = @("EOT")
    dev ${device}
    persist-tun
    txqueuelen 1000
    ca ${::settings::localcacert}
    cert ${::settings::certdir}/${::trusted['certname']}.pem
    key ${::settings::privatekeydir}/${::trusted['certname']}.pem
    crl-verify ${::settings::hostcrl}
    script-security 2
    up /etc/openvpn/up.sh
    down /etc/openvpn/down.sh
    down-pre
    verb 3
    | EOT

  $dnsmasq_config = @("EOT")
    resolv-file=/run/systemd/resolve/resolv.conf
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

    ::nest::lib::systemd_reload { 'dnsmasq':
      subscribe => File['/etc/systemd/system/dnsmasq.service.d/10-openvpn.conf'],
    }

    service { 'dnsmasq':
      enable  => true,
      require => [
        Nest::Lib::Systemd_reload['dnsmasq'],
        Service["openvpn-${mode}@nest"],
      ],
    }

    firewall {
      default:
        proto  => udp,
        dport  => 1194,
        state  => 'NEW',
        action => accept,
      ;

      '100 openvpn (v4)':
        provider => iptables,
      ;

      '100 openvpn (v6)':
        provider => ip6tables,
      ;
    }

    # Forwarding rules to control access to VPN
    firewall { '100 nest vpn: allow kvm guests':
      chain    => 'FORWARD',
      proto    => all,
      iniface  => 'virbr0',
      outiface => $device,
      action   => accept,
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

  # Allow and forward all VPN traffic
  firewall {
    default:
      proto => all,
    ;

    '001 nest vpn':
      iniface => $device,
      action  => accept,
    ;

    '001 nest vpn: forward all':
      chain   => 'FORWARD',
      iniface => $device,
      action  => accept,
    ;

    '002 nest vpn: allow return packets':
      chain    => 'FORWARD',
      outiface => $device,
      ctstate  => ['RELATED', 'ESTABLISHED'],
      action   => accept,
    ;
  }
}
