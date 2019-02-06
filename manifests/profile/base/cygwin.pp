class nest::profile::base::cygwin {
  package { 'cygwin':
    ensure => installed,
  }

  package { 'cygrunsrv':
    ensure   => installed,
    provider => 'cygwin',
    require  => Package['cygwin'],
  }

  # Ensure any files managed under the cygwin root implicitcly depend on
  # Package[cygwin]
  file { 'C:/tools/cygwin':
    require => Package['cygwin'],
  }

  exec { 'cygserver-config':
    command     => shellquote(
      'C:/tools/cygwin/bin/bash.exe', '-c',
      'source /etc/profile && /usr/bin/cygserver-config --yes'
    ),
    creates => 'C:/tools/cygwin/etc/cygserver.conf',
    require => Package['cygrunsrv'],
    notify  => Service['cygserver'],
  }

  service { 'cygserver':
    ensure  => running,
    enable  => true,
    require => Exec['cygserver-config'],
  }
}
