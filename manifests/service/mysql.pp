class nest::service::mysql {
  class { 'mysql::client':
    package_manage => false,
  }

  unless $facts['is_container'] {
    class { 'mysql::server':
      override_options => {
        'mysqld' => {
          'bind-address' => ['0.0.0.0', '::'],
        },
      },
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
