class nest::profile::workstation::lastpass {
  package { 'app-admin/lastpass-cli':
    ensure => installed,
  }

  exec { '/bin/mkdir -p /home/james/bin':
    unless  => '/usr/bin/test -d /home/james/bin',
    require => File['/home/james'],
  }

  file { '/home/james/bin':
    ensure  => directory,
    mode    => '0755',
    owner   => 'james',
    group   => 'users',
    require => Exec['/bin/mkdir -p /home/james/bin'],
  }

  file { '/home/james/bin/lpass-copy':
    mode    => '0755',
    owner   => 'james',
    group   => 'users',
    content => template('nest/lastpass/lpass-copy.erb'),
  } 
}
