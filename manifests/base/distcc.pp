class nest::base::distcc {
  package { 'sys-devel/distcc':
    ensure => installed,
  }

  $localhost_jobs = $::nest::processorcount + 1
  $distcc_hosts_content = $::nest::distcc_hosts.map |$host, $processorcount| {
    $jobs = $processorcount + 1
    "${host}/${jobs}\n"
  }.join('')

  file { '/etc/distcc/hosts':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "${distcc_hosts_content}localhost/${localhost_jobs}\n",
    require => Package['sys-devel/distcc'],
  }
}
