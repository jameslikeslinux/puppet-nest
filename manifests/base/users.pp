class nest::base::users {
  case $facts['osfamily'] {
    'Gentoo': {
      file { '/bin/zsh':
        ensure => file,
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
      }

      package { 'app-shells/zsh':
        ensure => installed,
      }

      file_line { 'useradd-group':
        path  => '/etc/default/useradd',
        line  => 'GROUP=1000',
        match => '^GROUP=',
      }

      group {
        'users':
          gid     => '1000',
          require => File_line['useradd-group'];
        'media':
          gid => '1001';
        'bitwarden':
          gid => '1003';
      }

      # This is because I abuse UIDs (I create "system" users like
      # plex above 1000, so useradd wants to create its home directory
      # by default).  We can explicitly control this behavior with the
      # 'managehome' attribute.
      file_line { 'login.defs-create_home':
        path  => '/etc/login.defs',
        line  => 'CREATE_HOME no',
        match => '^CREATE_HOME ',
      }

      unless $facts['build'] == 'stage1' or $facts['tool'] {
        $pw_hash = $::nest::pw_hash
      }

      user {
        default:
          managehome => false,
          require    => File_line['login.defs-create_home'],
        ;

        'root':
          shell    => '/bin/zsh',
          require  => File['/bin/zsh'],
          password => $pw_hash,
        ;

        'james':
          uid      => '1000',
          gid      => 'users',
          groups   => ['plugdev', 'video', 'wheel'],
          home     => '/home/james',
          comment  => 'James Lee',
          shell    => '/bin/zsh',
          password => $pw_hash,
          require  => [
            Package['app-shells/zsh'],
            Class['::nest::base::network'],  # networkmanager creates 'plugdev' group
          ],
        ;

        'ombi':
          uid     => '3579',
          gid     => 'media',
          home    => '/srv/ombi',
          comment => 'Ombi',
          shell   => '/sbin/nologin',
        ;

        'couchpotato':
          uid     => '5050',
          gid     => 'media',
          home    => '/srv/couchpotato',
          comment => 'CouchPotato',
          shell   => '/sbin/nologin',
        ;

        'nzbget':
          uid     => '6789',
          gid     => 'media',
          home    => '/srv/nzbget',
          comment => 'NZBGet',
          shell   => '/sbin/nologin',
        ;

        'radarr':
          uid     => '7878',
          gid     => 'media',
          home    => '/srv/radarr',
          comment => 'Radarr',
          shell   => '/sbin/nologin',
        ;

        'sonarr':
          uid     => '8989',
          gid     => 'media',
          home    => '/srv/sonarr',
          comment => 'Sonarr',
          shell   => '/sbin/nologin',
        ;

        'transmission':
          uid     => '9091',
          gid     => 'media',
          home    => '/srv/transmission',
          comment => 'Transmission',
          shell   => '/sbin/nologin',
        ;

        'plex':
          uid     => '32400',
          gid     => 'media',
          home    => '/srv/plex',
          comment => 'Plex Media Server',
          shell   => '/sbin/nologin',
        ;

        'bitwarden':
          uid     => '1003',
          gid     => '1003',
          home    => '/srv/bitwarden',
          comment => 'Bitwarden',
          shell   => '/bin/zsh',
        ;
      }

      file {
        '/root/.keep':
          ensure => absent,
          before => Vcsrepo['/root'],
        ;

        '/home/james':
          ensure => directory,
          mode   => '0755',
          owner  => 'james',
          group  => 'users',
          before => Vcsrepo['/home/james'],
        ;
      }

      $homes = {
        'root'  => '/root',
        'james' => '/home/james',
      }
    }

    'windows': {
      package { 'zsh':
        ensure   => installed,
        provider => 'cygwin',
      }

      windows_env { 'james-SHELL':
        user     => 'james',
        variable => 'SHELL',
        value    => '/bin/zsh',
        require  => Package['zsh'],
      }

      $homes = {
        'james' => '/home/james',
      }
    }
  }

  $homes.each |$user, $dir| {
    case $facts['osfamily'] {
      'windows': {
        $exec_user   = undef
        $home_dir    = "C:/tools/cygwin${dir}"
        $refresh_cmd = "C:/tools/cygwin/bin/bash.exe -c 'source /etc/profile && ${home_dir}/.refresh'"
        $test_cmd    = "C:/tools/cygwin/bin/test.exe -x ${home_dir}/.refresh"
      }

      default: {
        $exec_user   = $user
        $home_dir    = $dir
        $refresh_cmd = "${home_dir}/.refresh"
        $test_cmd    = "/usr/bin/test -x ${home_dir}/.refresh"
      }
    }

    vcsrepo { "$home_dir":
      ensure   => latest,
      provider => git,
      source   => 'https://gitlab.james.tl/james/dotfiles.git',
      revision => 'main',
      user     => $exec_user,
    }
    ~>
    exec { "refresh-${user}-home":
      command     => $refresh_cmd,
      user        => $exec_user,
      onlyif      => $test_cmd,
      refreshonly => true,
    }

    unless $facts['build'] == 'stage1' or $facts['tool'] {
      file { "${home_dir}/.ssh/id_rsa":
        mode      => '0600',
        owner     => $user,
        content   => $::nest::ssh_private_key,
        show_diff => false,
        require   => Vcsrepo[$home_dir],
      }
    }
  }
}
