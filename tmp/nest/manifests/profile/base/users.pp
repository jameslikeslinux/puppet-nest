class nest::profile::base::users {
  file { '/bin/zsh':
    ensure => file,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  package { 'app-shells/zsh':
    ensure => installed,
  }

  group { 'users':
    gid => '1000',
  }

  group { 'media':
    gid => '1001',
  }

  user {
    'root':
      shell   => '/bin/zsh',
      require => File['/bin/zsh'];

    'james':
      uid     => '1000',
      gid     => 'users',
      groups  => ['plugdev', 'wheel'],
      home    => '/home/james',
      comment => 'James Lee',
      shell   => '/bin/zsh',
      require => [
        Package['app-shells/zsh'],
        Class['::nest::profile::base::network'],  # networkmanager creates 'plugdev' group
      ];

    'nzbget':
      uid     => '6789',
      gid     => 'media',
      home    => '/srv/nzbget',
      comment => 'NZBGet',
      shell   => '/sbin/nologin';
  }

  file {
    '/root/.keep':
      ensure => absent;

    '/home/james':
      ensure => directory,
      mode   => '0755',
      owner  => 'james',
      group  => 'users';
  }

  vcsrepo {
    default:
      ensure   => latest,
      provider => git,
      source   => 'https://github.com/iamjamestl/profile.git',
      revision => 'master';

    '/root':
      require  => File['/root/.keep'];

    '/home/james':
      user     => 'james',
      require  => File['/home/james'];
  }

  file {
    default:
      mode      => '0600',
      content   => $::nest::ssh_private_key,
      show_diff => false;

    '/root/.ssh/id_rsa':
      owner     => 'root',
      group     => 'root',
      require   => Vcsrepo['/root'];

    '/home/james/.ssh/id_rsa':
      owner     => 'james',
      group     => 'users',
      require   => Vcsrepo['/home/james'];
  }
}
