class nest::profile::workstation::lastpass {
  package { 'app-admin/lastpass-cli':
    ensure => installed,
  }

  exec { '/bin/mkdir -p /home/james/.lastpass':
    unless  => '/usr/bin/test -d /home/james/.lastpass',
    require => File['/home/james'],
  }

  file { '/home/james/.lastpass':
    ensure  => directory,
    mode    => '0755',
    owner   => 'james',
    group   => 'users',
    require => Exec['/bin/mkdir -p /home/james/.lastpass'],
  }

  file { '/home/james/.lastpass/lpass-copy':
    mode    => '0755',
    owner   => 'james',
    group   => 'users',
    content => template('nest/lastpass/lpass-copy.erb'),
  }

  file { '/home/james/.lastpass/lastpass.khotkeys':
    mode   => '0644',
    owner  => 'james',
    group  => 'users',
    source => 'puppet:///modules/nest/lastpass/lastpass.khotkeys',
  }
}
