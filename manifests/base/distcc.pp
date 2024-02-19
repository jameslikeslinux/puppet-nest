class nest::base::distcc {
  tag 'build_prep'

  package { 'sys-devel/distcc':
    ensure => installed,
  }

  $distcc_hosts_config = $nest::distcc_hosts.delete("${trusted['certname']}.nest").map |$host, $jobs| { "${host}/${jobs}" }
  $localhost_config = "localhost/${nest::concurrency}"
  $distcc_hosts_content = $distcc_hosts_config ? {
    []      => "${localhost_config}\n",
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
