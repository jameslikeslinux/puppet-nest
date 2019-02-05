class nest::profile::base::git {
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

      $git_batch_content = @(END_GIT_BAT)
        @echo off
        C:/tools/cygwin/bin/git.exe %*
        | END_GIT_BAT

      file { 'C:/Program Files/Puppet Labs/Puppet/bin/git.bat':
        content => $git_batch_content,
        require => Package['git'],
      }
    }
  }
}
