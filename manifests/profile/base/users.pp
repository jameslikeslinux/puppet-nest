class nest::profile::base::users {
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
        'ubnt':
          ensure  => absent,
          gid     => '1002',
          require => User['ubnt'];
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

      user {
        default:
          managehome => false,
          require    => File_line['login.defs-create_home'];

        'root':
          shell    => '/bin/zsh',
          require  => File['/bin/zsh'],
          password => $::nest::pw_hash;

        'james':
          uid      => '1000',
          gid      => 'users',
          groups   => ['plugdev', 'video', 'wheel'],
          home     => '/home/james',
          comment  => 'James Lee',
          shell    => '/bin/zsh',
          password => $::nest::pw_hash,
          require  => [
            Package['app-shells/zsh'],
            Class['::nest::profile::base::network'],  # networkmanager creates 'plugdev' group
          ];

        'ombi':
          uid     => '3579',
          gid     => 'media',
          home    => '/srv/ombi',
          comment => 'Ombi',
          shell   => '/sbin/nologin';

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

        'radarr':
          uid     => '7878',
          gid     => 'media',
          home    => '/srv/radarr',
          comment => 'Radarr',
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

        'ubnt':
          ensure  => absent,
          uid     => '1002',
          gid     => '1002',
          home    => '/srv/unifi',
          comment => 'Ubiquiti UniFi',
          shell   => '/sbin/nologin';

        'bitwarden':
          uid     => '1003',
          gid     => '1003',
          home    => '/srv/bitwarden',
          comment => 'Bitwarden',
          shell   => '/bin/zsh';
      }

      file {
        '/root/.keep':
          ensure => absent,
          before => Vcsrepo['/root'];

        '/home/james':
          ensure => directory,
          mode   => '0755',
          owner  => 'james',
          group  => 'users';
      }

      if $facts['virtual'] == 'lxc' {
        $user_homes = {}
      } else {
        $user_homes = { 'james' => '/home/james' }
        File['/home/james'] -> Vcsrepo['/home/james']
      }

      $homes = { 'root'  => '/root' } + $user_homes
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
        $vcsrepo_user = undef
        $vcsrepo_dir  = "C:/tools/cygwin${dir}"
      }

      default: {
        $vcsrepo_user = $user
        $vcsrepo_dir  = $dir
      }
    }

    vcsrepo { "$vcsrepo_dir":
      ensure   => latest,
      provider => git,
      source   => 'https://github.com/iamjamestl/dotfiles.git',
      revision => 'master',
      user     => $vcsrepo_user,
      force    => true,
    }

    if $facts['osfamily'] == 'windows' {
      file { "${vcsrepo_dir}/.ssh/config.erb":
        mode   => '0600',
        before => Nest::Cygwin_home_perms['pre-refresh'],
        notify => Exec["refresh-${user}-dotfiles"],
      }

      ::nest::cygwin_home_perms { 'pre-refresh':
        user    => $user,
        require => Vcsrepo["$vcsrepo_dir"],
        before  => Exec["refresh-${user}-dotfiles"],
      }

      $user_quoted     = shellquote($user)
      $dir_quoted      = shellquote($dir)
      $refresh_command = shellquote(
        'C:/tools/cygwin/bin/bash.exe', '-c',
        "source /etc/profile && ${dir_quoted}/.refresh ${user_quoted}",
      )

      exec { "refresh-${user}-dotfiles":
        command     => $refresh_command,
        onlyif      => "C:/tools/cygwin/bin/test.exe -x '${dir_quoted}/.refresh'",
        refreshonly => true,
        subscribe   => Vcsrepo["$vcsrepo_dir"],
      }

      ::nest::cygwin_home_perms { 'post-refresh':
        user    => $user,
        require => [
          Exec["refresh-${user}-dotfiles"],
          File["${vcsrepo_dir}/.ssh/id_rsa"],
        ],
      }
    } else {
      exec { "${dir}/.refresh":
        user        => $user,
        onlyif      => "/usr/bin/test -x '${dir}/.refresh'",
        refreshonly => true,
        subscribe   => Vcsrepo[$vcsrepo_dir],
      }
    }

    file { "${vcsrepo_dir}/.ssh/id_rsa":
      mode      => '0600',
      owner     => $user,
      content   => $::nest::ssh_private_key,
      show_diff => false,
      require   => Vcsrepo[$vcsrepo_dir],
    }
  }
}
