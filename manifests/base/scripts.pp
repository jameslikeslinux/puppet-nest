class nest::base::scripts {
  File {
    mode  => '0755',
    owner => 'root',
    group => 'root',
  }

  file { '/usr/local/sbin/nest-install':
    source => 'puppet:///modules/nest/scripts/install.sh',
  }
}
