class nest::base::users {
  case $facts['os']['family'] {
    'Gentoo': {
      file { '/bin/zsh':
        ensure => file,
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
      }

      nest::lib::package { 'app-shells/zsh':
        ensure => installed,
      }

      group {
        'james':
          gid => '1000';
        'media':
          gid => '1001',
        ;
      }

      # Useradd wants to create home directories by default.  We can explicitly
      # control this behavior with the 'managehome' attribute.
      file_line { 'login.defs-create_home':
        path  => '/etc/login.defs',
        line  => 'CREATE_HOME no',
        match => '^CREATE_HOME ',
      }

      user {
        default:
          managehome => false,
          require    => File_line['login.defs-create_home'],
        ;

        'root':
          shell    => '/bin/zsh',
          require  => File['/bin/zsh'],
          password => $nest::pw_hash,
        ;

        'james':
          uid      => '1000',
          gid      => 'james',
          groups   => ['wheel'],
          home     => '/home/james',
          comment  => 'James Lee',
          shell    => '/bin/zsh',
          password => $nest::pw_hash,
          require  => Nest::Lib::Package['app-shells/zsh'],
        ;

        'media':
          uid     => '1001',
          gid     => 'media',
          home    => '/dev/null',
          comment => 'Media Services',
          shell   => '/sbin/nologin',
        ;
      }

      # Early stages often have hidden files blocking vcsrepo initialization
      exec { '/bin/rm -rf /root':
        unless => '/usr/bin/test -d /root/.git',
        before => File['/root'],
      }

      file {
        '/root':
          ensure => directory,
          mode   => '0700',
          owner  => 'root',
          group  => 'root',
          before => Vcsrepo['/root'],
        ;

        '/home/james':
          ensure => directory,
          mode   => '0755',
          owner  => 'james',
          group  => 'james',
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
    case $facts['os']['family'] {
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

    vcsrepo { $home_dir:
      ensure   => latest,
      provider => git,
      source   => 'https://gitlab.james.tl/james/dotfiles.git',
      revision => 'main',
      user     => $exec_user,
    }
    ~>
    exec { "refresh-${home_dir}":
      environment => "HOME=${home_dir}",
      command     => $refresh_cmd,
      user        => $exec_user,
      onlyif      => $test_cmd,
      refreshonly => true,
      subscribe   => Class['nest::base::puppet'],
    }

    if $nest::ssh_private_keys {
      if $nest::ssh_private_keys[$user] {
        file { "${home_dir}/.ssh/id_ed25519":
          mode      => '0600',
          owner     => $user,
          content   => $nest::ssh_private_keys[$user],
          show_diff => false,
          require   => Vcsrepo[$home_dir],
        }
      } else {
        file { "${home_dir}/.ssh/id_ed25519":
          ensure => absent,
        }
      }
    }
  }
}
