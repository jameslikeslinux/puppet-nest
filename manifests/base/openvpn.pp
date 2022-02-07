class nest::base::openvpn {
  $client_config = @("EOT")
    client
    nobind
    remote ${::nest::openvpn_hostname} 1194
    | EOT

  case $facts['os']['family'] {
    'Gentoo': {
      $device     = 'tun0'
      $hosts_file = '/etc/hosts.nest'

      $server_config = @("EOT")
        ncp-ciphers AES-128-GCM
        dh /etc/openvpn/dh4096.pem
        server 172.22.0.0 255.255.255.0
        topology subnet
        client-to-client
        keepalive 10 30

        # Sync with pushed options below
        dhcp-option DOMAIN gitlab.james.tl
        dhcp-option DOMAIN nest
        dhcp-option DNS 172.22.0.1

        # Windows only honors the last domain pushed
        push "dhcp-option DOMAIN gitlab.james.tl"
        push "dhcp-option DOMAIN nest"
        push "dhcp-option DNS 172.22.0.1"

        # Preferred routes are < 100 on Gentoo and Windows
        push "route-metric 100"

        # Windows needs a default route to recognize network
        push "route 0.0.0.0 0.0.0.0"

        # UniFi
        push "route 172.22.1.12"

        setenv HOSTS ${hosts_file}
        learn-address /etc/openvpn/learn-address.sh
        ifconfig-pool-persist nest-ipp.txt
        | EOT

      $common_config = @("EOT")
        dev ${device}
        persist-tun
        txqueuelen 1000
        ca /etc/puppetlabs/puppet/ssl/certs/ca.pem
        cert /etc/puppetlabs/puppet/ssl/certs/${::trusted['certname']}.pem
        key /etc/puppetlabs/puppet/ssl/private_keys/${::trusted['certname']}.pem
        crl-verify /etc/puppetlabs/puppet/ssl/crl.pem
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
        $mode   = 'server'
        $config = $server_config

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
        $mode   = 'client'
        $config = $client_config
      }

      $openvpn_package_name = 'net-vpn/openvpn'
      $openvpn_config_file  = "/etc/openvpn/${mode}/nest.conf"
      $openvpn_service      = "openvpn-${mode}@nest"

      file { "/etc/openvpn/${mode}":
        ensure  => directory,
        mode    => '0755',
        require => Package[$openvpn_package_name],
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

    'windows': {
      $common_config = @("EOT")
        dev tun
        persist-tun
        ca C:/ProgramData/PuppetLabs/puppet/etc/ssl/certs/ca.pem
        cert C:/ProgramData/PuppetLabs/puppet/etc/ssl/certs/${::trusted['certname']}.pem
        key C:/ProgramData/PuppetLabs/puppet/etc/ssl/private_keys/${::trusted['certname']}.pem
        crl-verify C:/ProgramData/PuppetLabs/puppet/etc/ssl/crl.pem
        down-pre
        verb 3
        | EOT

      $config = $client_config

      $openvpn_package_name = 'openvpn'
      $openvpn_config_file  = 'C:/Program Files/OpenVPN/config/nest.ovpn'
      $openvpn_service      = 'OpenVPNService'
    }
  }

  package { $openvpn_package_name:
    ensure => installed,
  }
  ->
  file { $openvpn_config_file:
    mode    => '0644',
    content => "${common_config}${config}",
  }
  ~>
  service { $openvpn_service:
    enable => true,
  }
}
