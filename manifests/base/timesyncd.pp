class nest::base::timesyncd {
  unless $facts['build'] == 'stage1' or $facts['tool'] {
    # NIST provides reliable, public time servers which are explicitly allowed to
    # be referenced by IP address.  See: https://tf.nist.gov/tf-cgi/servers.cgi.
    # Look them up here, randomly rotate them, and set them as the list of NTP
    # servers for timesyncd so that hosts without working DNS, such as those
    # without RTCs to support DNSSEC at boot, can still sync time.
    # See also: https://github.com/systemd/systemd/issues/5873
    $nist_time_server_ips = [
      'time-a-g.nist.gov', 'time-b-g.nist.gov', 'time-c-g.nist.gov', 'time-d-g.nist.gov', 'time-e-g.nist.gov',
      'time-a-wwv.nist.gov', 'time-b-wwv.nist.gov', 'time-c-wwv.nist.gov', 'time-d-wwv.nist.gov', 'time-e-wwv.nist.gov',
      'time-a-b.nist.gov', 'time-b-b.nist.gov', 'time-c-b.nist.gov', 'time-d-b.nist.gov', 'time-e-b.nist.gov',
      'utcnist.colorado.edu', 'utcnist2.colorado.edu',
    ].map |$server| { [dns_aaaa($server), dns_a($server)] }.fqdn_rotate.flatten.join(' ')

    file_line { 'timesyncd.conf-NTP':
      path   => '/etc/systemd/timesyncd.conf',
      line   => "NTP=${nist_time_server_ips}",
      match  => '^#?NTP=',
      notify => Service['systemd-timesyncd'],
    }
  }

  service { 'systemd-timesyncd':
    enable => true,
  }
}
