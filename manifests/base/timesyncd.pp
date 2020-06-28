class nest::base::timesyncd {
  # NIST provides reliable, public time servers which are explicitly allowed to
  # be referenced by IP address.  See: https://tf.nist.gov/tf-cgi/servers.cgi.
  # Look them up here, randomly rotate them, and set them as the list of NTP
  # servers for timesyncd so that hosts without working DNS, such as those
  # without RTCs to support DNSSEC at boot, can still sync time.
  # See also: https://github.com/systemd/systemd/issues/5873
  $nist_time_server_ips = $nest::nist_time_servers.map |$server| { [dns_aaaa($server), dns_a($server)] }.fqdn_rotate.flatten.join(' ')

  file_line { 'timesyncd.conf-NTP':
    path   => '/etc/systemd/timesyncd.conf',
    line   => "NTP=${nist_time_server_ips}",
    match  => '^#?NTP=',
    notify => Service['systemd-timesyncd'],
  }

  service { 'systemd-timesyncd':
    enable => true,
  }
}
