class nest::profile::base::openvpn {
  $common_config = @("EOT")
    dev tun
    ca ${::settings::localcacert}
    cert ${::settings::hostcert}
    key ${::settings::hostprivkey}
    crl-verify ${::settings::hostcrl}
    | EOT

  $server_config = @(EOT)
    dh /etc/openvpn/dh4096.pem
    server 172.22.2.0 255.255.255.0
    topology subnet
    client-to-client
    keepalive 10 60
    push "dhcp-option DOMAIN james.tl"
    push "dhcp-option DNS 172.22.2.1"
    script-security 2
    learn-address /etc/openvpn/learn-address.sh
    | EOT

  $client_config = @(EOT)
    client
    remote vpn.james.tl 1194
    script-security 2
    up /etc/openvpn/up.sh
    down /etc/openvpn/down.sh
    down-pre
    | EOT

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

    contain '::nest::profile::base::resolvconf'
    contain '::nest::profile::base::dnsmasq'

    file { '/etc/openvpn/learn-address.sh':
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      source  => 'puppet:///modules/nest/openvpn/learn-address.sh',
      require => Package['net-misc/openvpn'],
      before  => Service["openvpn-${mode}@nest"],
    }

    file { '/etc/hosts.openvpn-clients':
      ensure => file,
      mode   => '0644',
      owner  => 'root',
      group  => 'root',
    }

    file_line { "hosts.openvpn-clients-${::trusted['certname']}":
      path    => '/etc/hosts.openvpn-clients',
      line    => "172.22.2.1\t${::trusted['certname']}",
      require => File['/etc/hosts.openvpn-clients'],
      notify  => Class['::nest::profile::base::dnsmasq'],
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
    owner   => 'root',
    group   => 'root',
    require => Package['net-misc/openvpn'],
  }

  file { "/etc/openvpn/${mode}/nest.conf":
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "${common_config}${mode_config}",
  }

  service { "openvpn-${mode}@nest":
    enable    => true,
    subscribe => File["/etc/openvpn/${mode}/nest.conf"],
  }
}
