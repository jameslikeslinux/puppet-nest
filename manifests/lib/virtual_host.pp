define nest::lib::virtual_host (
  String[1] $servername,
  Array[String[1]] $serveraliases                    = [],
  Optional[Variant[String[1], Array[String[1]]]] $ip = undef,
  Optional[Integer] $port                            = undef,
  Boolean $ssl                                       = true,
  Hash[String[1], Any] $extra_params                 = {},
  Boolean $zfs_docroot                               = true,
  Optional[String[1]] $priority                      = undef,
) {
  include '::nest::service::apache'

  $http_port = $port ? {
    undef   => 80,
    default => $port,
  }

  $https_port = $port ? {
    undef   => 443,
    default => $port,
  }

  $vhost_redirect_port = $port ? {
    undef   => '',
    default => ":${port}",
  }

  if $port and $::nest::service::apache::manage_firewall {
    firewall {
      default:
        proto  => tcp,
        dport  => $port,
        state  => 'NEW',
        action => accept,
      ;

      "100 ${name} (v4)":
        provider => iptables,
      ;

      "100 ${name} (v6)":
        provider => ip6tables,
      ;
    }
  }

  ensure_resource('apache::listen', $http_port, {})

  ensure_resource('nest::lib::srv', "www/${servername}", { zfs => $zfs_docroot })

  if $ssl {
    ensure_resource('apache::listen', $https_port, {})

    $vhost_name   = "${name}-ssl"
    $vhost_params = {
      'port'     => $https_port,
      'ssl'      => true,
      'ssl_cert' => "/etc/letsencrypt/live/${servername}/fullchain.pem",
      'ssl_key'  => "/etc/letsencrypt/live/${servername}/privkey.pem",
    }
    $vhost_redirect_proto = 'https'

    unless $port {
      apache::vhost { "${name}-redirect":
        priority        => $priority,
        servername      => $servername,
        serveraliases   => $serveraliases,
        ip              => $ip,
        port            => '80',
        add_listen      => false,
        docroot         => "/srv/www/${servername}",
        docroot_owner   => 'james',
        docroot_group   => 'users',
        redirect_status => 'permanent',
        redirect_dest   => "https://${servername}/",
        require         => Nest::Lib::Srv["www/${servername}"],
      }
    }
  } else {
    $vhost_name   = $name
    $vhost_params = {
      'port' => $http_port,
    }
    $vhost_redirect_proto = 'http'
  }

  apache::vhost { $vhost_name:
    priority      => $priority,
    servername    => $servername,
    ip            => $ip,
    add_listen    => false,
    docroot       => "/srv/www/${servername}",
    docroot_owner => 'james',
    docroot_group => 'users',
    require       => Nest::Lib::Srv["www/${servername}"],
    *             => $vhost_params + $extra_params,
  }

  unless empty($serveraliases) {
    apache::vhost { "${vhost_name}-redirect":
      priority        => $priority,
      servername      => $serveraliases[0],
      serveraliases   => $serveraliases[1, -1],
      ip              => $ip,
      add_listen      => false,
      docroot         => "/srv/www/${servername}",
      docroot_owner   => 'james',
      docroot_group   => 'users',
      redirect_status => 'permanent',
      redirect_dest   => "${vhost_redirect_proto}://${servername}${vhost_redirect_port}/",
      require         => Nest::Lib::Srv["www/${servername}"],
      *               => $vhost_params,
    }
  }
}
