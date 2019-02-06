class nest::profile::base::cygwin {
  package { 'cygwin':
    ensure => installed,
  }

  $fix_perms_content = @(END_FIX_PERMS)
    find "$(cygpath -am /)" -not -path "$(cygpath -am /home)/*" -not -path "*/tmp/*" | xargs cygpath | xargs chown -h Administrators
    | END_FIX_PERMS

  file { 'C:/tools/cygwin/etc/postinstall/zp_fix-perms.sh':
    content => $fix_perms_content,
    notify  => Exec['cygwin-fix-perms'],
    require => Package['cygwin'],
  }

  exec { 'cygserver-config':
    command     => shellquote(
      'C:/tools/cygwin/bin/bash.exe', '-c',
      'source /etc/profile && /usr/bin/cygserver-config --yes'
    ),
    creates => 'C:/tools/cygwin/etc/cygserver.conf',
    require => Package['cygwin'],
    notify  => [
      Exec['cygwin-fix-perms'],
      Service['cygserver'],
    ],
  }

  exec { 'cygwin-fix-perms':
    command     => shellquote(
      'C:/tools/cygwin/bin/bash.exe', '-c',
      'source /etc/profile && source /etc/postinstall/zp_fix-perms.sh'
    ),
    refreshonly => true,
  }

  service { 'cygserver':
    ensure  => running,
    enable  => true,
    require => [
      Exec['cygserver-config'],
      Exec['cygwin-fix-perms'],
    ],
  }
}
