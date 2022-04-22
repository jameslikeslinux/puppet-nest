class nest::base::timesyncd {
  # XXX cleanup
  file_line { 'timesyncd.conf-NTP':
    path  => '/etc/systemd/timesyncd.conf',
    line  => '#NTP=',
    match => '^#?NTP=',
  }
  ~>
  service { 'systemd-timesyncd':
    enable => true,
  }
}
