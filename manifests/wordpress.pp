define nest::wordpress (
  String[1] $db_password,
  String[1] $servername,
  Array[String[1]] $serveraliases                    = [],
  Optional[Variant[String[1], Array[String[1]]]] $ip = undef,
  Boolean $ssl                                       = true,
  Hash[String[1], Any] $extra_vhost_params           = {},
  Optional[String[1]] $priority                      = undef,
) {
  unless defined(Class['::nest::apache']) {
    class { '::nest::apache':
      manage_firewall => true,
    }
  }

  include '::nest::mysql'
  include '::nest::php'
  include '::apache::mod::proxy'
  include '::apache::mod::rewrite'
  ensure_resource('apache::mod', 'proxy_fcgi', { 'package' => 'www-servers/apache' })

  mysql::db { $name:
    user     => $name,
    password => $db_password,
  }

  $vhost_params = {
    'custom_fragment' => 'AddType application/x-httpd-php .php',
    'directories'     => [
      {
        'path'           => "/srv/www/${servername}",
        'options'        => ['Indexes', 'FollowSymLinks', 'MultiViews'],

        # Straight lifted from https://github.com/puppetlabs/puppetlabs-apache#rewrites-1
        'rewrites'       => [
          {
            'rewrite_base' => '/'
          },
          {
            'rewrite_rule' => [ '^index\.php$ - [L]' ]
          },
          {
            'rewrite_cond' => [
              '%{REQUEST_FILENAME} !-f',
              '%{REQUEST_FILENAME} !-d',
            ],
            'rewrite_rule' => [ '. /index.php [L]' ],
          },
        ],
      },
    ],
  }

  nest::vhost { $name:
    priority      => $priority,
    servername    => $servername,
    serveraliases => $serveraliases,
    ip            => $ip,
    ssl           => $ssl,
    extra_params  => $vhost_params + $extra_vhost_params,
    zfs_docroot   => true,
  }
}
