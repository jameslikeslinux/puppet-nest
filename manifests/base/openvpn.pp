class nest::base::openvpn {
  case $facts['os']['family'] {
    'Gentoo': {
      $dnsmasq_config = @("EOT")
        resolv-file=/run/systemd/resolve/resolv.conf
        no-hosts
        addn-hosts=/etc/hosts.nest
        expand-hosts
        domain=nest
        enable-dbus
        | EOT

      $openvpn_package_name = 'net-vpn/openvpn'
      $openvpn_package_opts = undef

      File {
        owner => 'root',
        group => 'root',
      }

      if $nest::openvpn {
        $mode = 'server'
        $openvpn_config = epp('nest/openvpn/config.epp', { 'server' => udp })

        exec { 'openvpn-create-dh-parameters':
          command => '/usr/bin/openssl dhparam -out /etc/openvpn/dh4096.pem 4096',
          creates => '/etc/openvpn/dh4096.pem',
          timeout => 0,
          require => Package['net-vpn/openvpn'],
          before  => Service["openvpn-${mode}@nest"],
        }

        file {
          default:
            require => Package['net-vpn/openvpn'],
            before  => Service["openvpn-${mode}@nest"],
          ;
          '/etc/openvpn/.manage-hosts.sh':
            mode   => '0755',
            source => 'puppet:///modules/nest/openvpn/manage-hosts.sh',
          ;
          [
            '/etc/openvpn/client-connect.sh',
            '/etc/openvpn/client-disconnect.sh',
          ]:
            ensure => link,
            target => '.manage-hosts.sh',
          ;
        }

        file { '/etc/hosts.nest':
          ensure => file,
          mode   => '0644',
        }

        host { $::trusted['certname']:
          ip      => '172.22.0.1',
          target  => '/etc/hosts.nest',
          require => File['/etc/hosts.nest'],
          notify  => Service['dnsmasq'],
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

          '/etc/dnsmasq.d/host-records.conf':
            content => $nest::host_records.map |$name, $ip| { "host-record=${name},${ip}\n" }.join(''),
          ;
        }

        Service <| title == 'dnsmasq' |> {
          require +> Service["openvpn-${mode}@nest"],
        }

        nest::lib::external_service { 'openvpn': }

        #
        # Manage TCP service
        #
        file { '/etc/openvpn/server/nest-tcp.conf':
          mode    => '0644',
          content => epp('nest/openvpn/config.epp', { 'server' => tcp }),
          require => Package[$openvpn_package_name],
        }
        ~>
        service { 'openvpn-server@nest-tcp':
          enable => true,
        }

        # Override built-in openvpn service to add TCP port
        firewalld_custom_service { 'openvpn':
          ensure => present,
          ports  => [
            { 'port' => '1194', 'protocol' => 'udp' },
            { 'port' => '1194', 'protocol' => 'tcp' },
          ],
          # autobefore Firewalld_service['openvpn']
        }

        # Disable client service that may have been enabled in early build stage
        service { 'openvpn-client@nest':
          enable => false,
        }
      } else {
        $mode = 'client'
        $openvpn_config = epp('nest/openvpn/config.epp')
      }

      $openvpn_config_file  = "/etc/openvpn/${mode}/nest.conf"
      $openvpn_service      = "openvpn-${mode}@nest"

      file { "/etc/openvpn/${mode}":
        ensure  => directory,
        mode    => '0755',
        require => Package[$openvpn_package_name],
      }
    }

    'windows': {
      $openvpn_package_name = 'openvpn'
      $openvpn_package_opts = ['--package-parameters', '"', '/Service', '/TapDriver', '"']
      $openvpn_config_file  = 'C:/Program Files/OpenVPN/config-auto/nest.ovpn'
      $openvpn_config       = epp('nest/openvpn/config.epp')
      $openvpn_service      = 'OpenVPNService'
    }
  }

  package { $openvpn_package_name:
    ensure          => installed,
    install_options => $openvpn_package_opts,
  }
  ->
  file { $openvpn_config_file:
    mode    => '0644',
    content => $openvpn_config,
  }
  ~>
  service { $openvpn_service:
    enable => $nest::vpn_client,
  }
}
