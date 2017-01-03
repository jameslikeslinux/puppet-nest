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
      ensure => absent,
      before => Vcsrepo['/root'];

    '/home/james':
      ensure => directory,
      mode   => '0755',
      owner  => 'james',
      group  => 'users',
      before => Vcsrepo['/home/james'];
  }

  $homes = {
    'root'  => '/root',
    'james' => '/home/james',
  }

  $homes.each |$user, $dir| {
    vcsrepo { $dir:
      ensure   => latest,
      provider => git,
      source   => 'https://github.com/iamjamestl/dotfiles.git',
      revision => 'master',
      user     => $user,
    }

    file { "${dir}/.ssh/id_rsa":
      mode      => '0600',
      owner     => $user,
      content   => $::nest::ssh_private_key,
      show_diff => false,
      require   => Vcsrepo[$dir],
    }

    exec { "${dir}/.refresh":
      user        => $user,
      path        => '/usr/bin:/bin',
      onlyif      => "test -x '${dir}/.refresh'",
      refreshonly => true,
      subscribe   => Vcsrepo[$dir],
    }
  }
}
