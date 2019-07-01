class nest::profile::base::distcc {
  package { 'sys-devel/distcc':
    ensure => installed,
  }

  $localhost_jobs = $::nest::processorcount + 1
  $distcc_hosts_content = $::nest::distcc_hosts.map |$host, $processorcount| {
    $jobs = $processorcount + 1
    "${host}/${jobs},cpp,lzo\n"
  }.join('')

  file { '/etc/distcc/hosts':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "localhost/${localhost_jobs}\n${distcc_hosts_content}",
    require => Package['sys-devel/distcc'],
  }

  file { "/usr/lib/distcc/bin/${::toolchain}-wrapper":
    ensure  => absent,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => template('nest/distcc/wrapper.sh.erb'),
    require => Package['sys-devel/distcc'],
  }

  # Disable cross-compilation compatibility until we need this functionality.
  # See: https://wiki.gentoo.org/wiki/Distcc/Cross-Compiling
  #
  # file { [
  #   '/usr/lib/distcc/bin/c++',
  #   '/usr/lib/distcc/bin/cc',
  #   '/usr/lib/distcc/bin/g++',
  #   '/usr/lib/distcc/bin/gcc',
  # ]:
  #   ensure  => link,
  #   target  => "/usr/lib/distcc/bin/${::toolchain}-wrapper",
  #   require => File["/usr/lib/distcc/bin/${::toolchain}-wrapper"],
  # }
}
