class nest::profile::workstation::pulseaudio {
  # If pulseaudio isn't started by systemd, then it gets started by the
  # the first thing to use it, like mpd; and when it does, it will respawn
  # itself like a virus, preventing clean shutdowns.
  exec { 'pulseaudio-enable-systemd-user-service':
    command => '/bin/systemctl --user --global enable pulseaudio.socket',
    creates => '/etc/systemd/user/sockets.target.wants/pulseaudio.socket',
  }

  $default_sample_format_line = $::nest::pulse_sample_format ? {
    undef   => '; default-sample-format = s16le',
    default => "default-sample-format = ${::nest::pulse_sample_format}",
  }

  file_line { 'pulse-daemon.conf-default-sample-format':
    path  => '/etc/pulse/daemon.conf',
    match => 'default-sample-format = ',
    line  => $default_sample_format_line,
  }
}
