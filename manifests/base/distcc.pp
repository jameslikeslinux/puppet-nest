class nest::base::distcc {
  package { 'sys-devel/distcc':
    ensure => installed,
  }

  $localhost_jobs = $::nest::processorcount
  $distcc_hosts_config = $::nest::distcc_hosts.map |$host, $processorcount| {
    $jobs = $processorcount
    "${host}/${jobs}"
  }
  $localhost_config = "localhost/${localhost_jobs}"
  $distcc_hosts_content = empty($distcc_hosts_config) ? {
    true    => "${localhost_config}\n",
    default => "${distcc_hosts_config.join("\n")}\n${localhost_config}\n",
  }

  file { '/etc/distcc/hosts':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $distcc_hosts_content,
    require => Package['sys-devel/distcc'],
  }
}
