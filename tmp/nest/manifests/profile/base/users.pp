class nest::profile::base::users {
  group { 'users':
    gid => '1000',
  }

  user { 'james':
    uid     => '1000',
    gid     => 'users',
    groups  => ['wheel'],
    home    => '/home/james',
    comment => 'James Lee',
    shell   => '/bin/zsh',
  }

  file { '/home/james':
    ensure => directory,
    mode   => '0755',
    owner  => 'james',
    group  => 'users',
  }

  vcsrepo { '/home/james':
    ensure   => latest,
    provider => git,
    source   => 'https://github.com/MrStaticVoid/profile.git',
    revision => 'master',
    user     => 'james',
    require  => File['/home/james'],
  }

  file { '/home/james/.ssh/id_rsa':
    mode      => '0600',
    owner     => 'root',
    group     => 'root',
    content   => $::nest::ssh_private_key,
    show_diff => false,
    require   => Vcsrepo['/home/james'],
  }

  file { '/home/james/.ssh/id_rsa.pub':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "${::nest::ssh_public_key}\n",
    require => Vcsrepo['/home/james'],
  }
}
