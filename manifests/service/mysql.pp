class nest::service::mysql (
  Sensitive $root_password,
) {
  class { 'mysql::client':
    package_manage => false,
  }

  unless $facts['is_container'] {
    class { 'mysql::server':
      override_options => {
        'mysqld' => {
          'bind-address'      => '0.0.0.0',
          'skip_name_resolve' => true,
          'ssl-ca'            => undef,
          'ssl-cert'          => undef,
          'ssl-key'           => undef,
        },
      },
      root_password    => $root_password,
      service_name     => 'mysqld',
      service_provider => 'systemd',
    }

    exec { 'mysql-tmpfiles-create':
      command => '/usr/bin/systemd-tmpfiles --create /usr/lib/tmpfiles.d/mysql.conf',
      creates => '/run/mysqld',
      require => Class['mysql::server::install'],
      before  => Class['mysql::server::service'],
    }
  }
}
