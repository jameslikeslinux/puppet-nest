class nest::role::workstation::pipewire {
  nest::lib::package { 'media-video/pipewire':
    ensure => installed,
    use    => ['aptx', 'ldac'],
  }
  ->
  exec {
    'systemd-enable-pipewire':
      command => '/bin/systemctl --user --global enable pipewire.socket',
      creates => '/etc/systemd/user/sockets.target.wants/pipewire.socket',
    ;

    'systemd-enable-pipewire-pulse':
      command => '/bin/systemctl --user --global enable pipewire-pulse.socket',
      creates => '/etc/systemd/user/sockets.target.wants/pipewire-pulse.socket',
    ;

    'systemd-enable-pipewire-media-session':
      command => '/bin/systemctl --user --global enable pipewire-media-session.service',
      creates => '/etc/systemd/user/pipewire.service.wants/pipewire-media-session.service',
    ;
  }

  nest::lib::package { 'media-sound/pulseaudio':
    world => false,
  }
  ->
  file_line { 'pulse-client.conf-disable-autospawn':
    path  => '/etc/pulse/client.conf',
    match => '^(; )?autospawn = ',
    line  => 'autospawn = no',
  }


  #
  # XXX: Cleanup PulseAudio
  #
  exec { 'systemd-disable-pulseaudio':
    command => '/bin/systemctl --user --global disable pulseaudio.socket',
    onlyif  => '/usr/bin/test -e /etc/systemd/user/sockets.target.wants/pulseaudio.socket',
  }

  package { 'media-sound/pulseaudio-modules-bt':
    ensure => absent,
  }

  file_line { 'pulse-default.pa-include-nest.pa':
    ensure => absent,
    path   => '/etc/pulse/default.pa',
    line   => '.include /etc/pulse/nest.pa',
  }

  file { '/etc/pulse/nest.pa':
    ensure => absent,
  }
}
