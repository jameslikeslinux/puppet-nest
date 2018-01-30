class nest::profile::base::distccd {
  if $::nest::distcc_server {
    $disable_verbose_content = @(EOT)
      [Service]
      ExecStart=
      ExecStart=/usr/bin/distccd --no-detach --daemon --port 3632 -N 15 --allow 172.22.2.0/24
      | EOT

    file { '/etc/systemd/system/distccd.service.d/10-nest.conf':
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => $disable_verbose_content,
      notify  => Exec['distccd-systemd-daemon-reload'],
    }

    exec { 'distccd-systemd-daemon-reload':
      command     => '/bin/systemctl daemon-reload',
      refreshonly => true,
      notify      => Service['distccd']
    }

    service { 'distccd':
      enable => true,
    }
  }
}
