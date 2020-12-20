class nest::base::distccd {
  if $::nest::distcc_server {
    $disable_verbose_content = @(EOT)
      [Service]
      ExecStart=
      ExecStart=/usr/bin/distccd --no-detach --daemon --port 3632 -N 15 --allow 0.0.0.0/0
      | EOT

    file { '/etc/systemd/system/distccd.service.d/10-nest.conf':
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => $disable_verbose_content,
      notify  => Nest::Lib::Systemd_reload['distccd'],
    }

    ::nest::lib::systemd_reload { 'distccd':
      notify => Service['distccd']
    }

    service { 'distccd':
      enable => true,
    }
  }
}
