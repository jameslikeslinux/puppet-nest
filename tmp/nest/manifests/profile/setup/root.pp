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
}
