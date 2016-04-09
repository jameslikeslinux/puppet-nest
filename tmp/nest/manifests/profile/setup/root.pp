class nest::profile::setup::root {
  package { 'app-shells/zsh':
    ensure => installed,
  }

  user { 'root':
    shell   => '/bin/zsh',
    require => Package['app-shells/zsh'],
  }

  file { '/root/.keep':
    ensure => absent,
  }

  vcsrepo { '/root':
    ensure   => latest,
    provider => git,
    source   => 'https://github.com/MrStaticVoid/profile.git',
    require  => File['/root/.keep'],
  }

  file { '/root/.ssh/id_rsa':
    mode      => '0600',
    owner     => 'root',
    group     => 'root',
    content   => $::nest::ssh_private_key,
    show_diff => false,
    require   => Vcsrepo['/root'],
  }

  file { '/root/.ssh/id_rsa.pub':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $::nest::ssh_public_key,
    require => Vcsrepo['/root'],
  }
}
