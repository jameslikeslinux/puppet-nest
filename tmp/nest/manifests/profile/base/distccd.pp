class nest::profile::base::distccd {
  if $::nest::distcc_server {
    file_line { 'distccd-allowed-servers':
      path  => '/etc/systemd/system/distccd.service.d/00gentoo.conf',
      line  => 'Environment="ALLOWED_SERVERS=172.22.2.0/24"',
      match => '^Environment="ALLOWED_SERVERS=',
    }

    exec { 'distccd-systemd-daemon-reload':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      subscribe   => File_line['distccd-allowed-servers'],
      notify      => Service['distccd']
    }

    service { 'distccd':
      enable => true,
    }
  }
}
