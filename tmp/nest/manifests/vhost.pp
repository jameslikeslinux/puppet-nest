define nest::vhost (
  String[1] $servername,
  Array[String[1]] $serveraliases                    = [],
  Optional[Variant[String[1], Array[String[1]]]] $ip = undef,
  Boolean $ssl                                       = true,
  Hash[String[1], Any] $extra_params                 = {},
  Boolean $zfs_docroot                               = true,
  Optional[String[1]] $priority                      = undef,
) {
  include '::nest::apache'

  ensure_resource('apache::listen', '80', {})

  nest::srv { "www/${servername}":
    zfs => $zfs_docroot,
  }

  if $ssl {
    ensure_resource('apache::listen', '443', {})

    $vhost_name   = "${servername}-ssl"
    $vhost_params = {
      'port'     => '443',
      'ssl'      => true,
      'ssl_cert' => "/etc/letsencrypt/live/${servername}/fullchain.pem",
      'ssl_key'  => "/etc/letsencrypt/live/${servername}/privkey.pem",
    }
    $vhost_redirect_to = 'https'

    apache::vhost { "${servername}-redirect":
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
      require         => Nest::Srv["www/${servername}"],
    }
  } else {
    $vhost_name   = $servername
    $vhost_params = {
      'port' => '80'
    }
    $vhost_redirect_to = 'http'
  }

  apache::vhost { $vhost_name:
    priority         => $priority,
    servername       => $servername,
    ip               => $ip,
    add_listen       => false,
    docroot          => "/srv/www/${servername}",
    docroot_owner    => 'james',
    docroot_group    => 'users',
    require          => Nest::Srv["www/${servername}"],
    *                => $vhost_params + $extra_params,
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
      redirect_dest   => "${vhost_redirect_to}://${servername}/",
      require         => Nest::Srv["www/${servername}"],
      *               => $vhost_params,
    }
  }
}
