class nest::service::mysql {
  class { '::mysql::client':
    package_manage => false,
  }

  class { '::mysql::server':
    override_options => {
      'mysqld' => {
        'bind-address' => ['0.0.0.0', '::'],
      }
    },
    service_name     => 'mysqld',
    service_provider => 'systemd',
  }

  unless $facts['is_container'] {
    exec { 'mysql-tmpfiles-create':
      command => '/usr/bin/systemd-tmpfiles --create /usr/lib/tmpfiles.d/mysql.conf',
      creates => '/run/mysqld',
      require => Class['::mysql::server::install'],
      before  => Class['::mysql::server::service'],
    }
  }
}
