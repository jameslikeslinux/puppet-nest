class nest::base::git {
  $package_name = $facts['osfamily'] ? {
    'Gentoo' => 'dev-vcs/git',
    default  => git,
  }

  case $facts['osfamily'] {
    'Gentoo': {
      package { 'dev-vcs/git':
        ensure => installed,
      }
    }

    'windows': {
      package { 'git':
        ensure   => installed,
        provider => 'cygwin',
      }

      $git_win_wrapper_content = @(END_GIT_WIN_WRAPPER)
        #!/bin/bash
        if (( $# > 0 )); then
            cygpath -- "$@" | xargs git
        else
            exec git
        fi
        | END_GIT_WIN_WRAPPER

      file { 'C:/tools/cygwin/usr/local/bin/git-win':
        mode    => '0755',
        owner   => 'Administrators',
        group   => 'None',
        content => $git_win_wrapper_content,
        require => Package['git'],
      }

      $git_batch_content = @(END_GIT_BAT)
        @echo off
        setlocal
        set PATH=C:/tools/cygwin/bin
        C:/tools/cygwin/bin/bash C:/tools/cygwin/usr/local/bin/git-win %*
        | END_GIT_BAT

      file { 'C:/Program Files/Puppet Labs/Puppet/bin/git.bat':
        content => $git_batch_content,
        require => File['C:/tools/cygwin/usr/local/bin/git-win'],
      }
    }
  }
}
