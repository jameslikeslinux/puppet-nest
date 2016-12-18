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

  group {
    'users':
      gid => '1000';
    'media':
      gid => '1001';
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

    'couchpotato':
      uid     => '5050',
      gid     => 'media',
      home    => '/srv/couchpotato',
      comment => 'CouchPotato',
      shell   => '/sbin/nologin';

    'nzbget':
      uid     => '6789',
      gid     => 'media',
      home    => '/srv/nzbget',
      comment => 'NZBGet',
      shell   => '/sbin/nologin';

    'sonarr':
      uid     => '8989',
      gid     => 'media',
      home    => '/srv/sonarr',
      comment => 'Sonarr',
      shell   => '/sbin/nologin';

    'transmission':
      uid     => '9091',
      gid     => 'media',
      home    => '/srv/transmission',
      comment => 'Transmission',
      shell   => '/sbin/nologin';

    'plex':
      uid     => '32400',
      gid     => 'media',
      home    => '/srv/plex',
      comment => 'Plex Media Server',
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
