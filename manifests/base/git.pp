class nest::base::git {
  case $facts['osfamily'] {
    'Gentoo': {
      package { 'dev-vcs/git':
        ensure => installed,
      }
    }

    'windows': {
      package { [
        'git',
        'ruby',
      ]:
        ensure   => installed,
        provider => 'cygwin',
      }

      # Windows and Puppet don't really support assuming other user contexts,
      # but Cygwin has managed to hack it into `setuid` when coming from the
      # SYSTEM account.  Force git to operate as my user so I can work in repos
      # that `vcsrepo` manages.  This hack could be made more generic with a new
      # custom type, but it's not worth the effort for just my home directory.
      $git_wrapper_content = @(END_GIT_WRAPPER)
        #!/bin/ruby
        Process::Sys.setuid('james')
        exec '/bin/git', *ARGV
        | END_GIT_WRAPPER

      $git_batch_content = @(END_GIT_BAT)
        @echo off
        setlocal
        C:/tools/cygwin/bin/ruby C:/tools/cygwin/usr/local/bin/git %*
        | END_GIT_BAT

      file {
        default:
          mode  => '0755',
          owner => 'Administrators',
          group => 'None',
        ;

        'C:/tools/cygwin/usr/local/bin/git':
          content => $git_wrapper_content,
          require => Package['git', 'ruby'],
        ;

        'C:/Program Files/Puppet Labs/Puppet/bin/git.bat':
          content => $git_batch_content,
          require => File['C:/tools/cygwin/usr/local/bin/git'],
        ;
      }
    }
  }
}
