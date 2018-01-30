class nest::profile::workstation::pulseaudio {
  # If pulseaudio isn't started by systemd, then it gets started by the
  # the first thing to use it, like mpd; and when it does, it will respawn
  # itself like a virus, preventing clean shutdowns.
  exec { 'pulseaudio-enable-systemd-user-service':
    command => '/bin/systemctl --user --global enable pulseaudio.socket',
    creates => '/etc/systemd/user/sockets.target.wants/pulseaudio.socket',
  }
}
