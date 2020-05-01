class nest::role::workstation::pulseaudio {
  # If pulseaudio isn't started by systemd, then it gets started by the
  # the first thing to use it, like mpd; and when it does, it will respawn
  # itself like a virus, preventing clean shutdowns.
  exec { 'pulseaudio-enable-systemd-user-service':
    command => '/bin/systemctl --user --global enable pulseaudio.socket',
    creates => '/etc/systemd/user/sockets.target.wants/pulseaudio.socket',
  }

  file_line { 'pulse-daemon.conf-default-sample-format':
    path  => '/etc/pulse/daemon.conf',
    match => '^(; )?default-sample-format = ',
    line  => 'default-sample-format = s24le',
  }

  nest::lib::portage::package_use { 'media-sound/pulseaudio-modules-bt':
    use => 'fdk',  # for AAC
  }

  # To support AAC for my Pixel Buds
  package { 'media-sound/pulseaudio-modules-bt':
    ensure => installed,
  }

  file_line { 'pulse-default.pa-include-nest.pa':
    path => '/etc/pulse/default.pa',
    line => '.include /etc/pulse/nest.pa',
  }

  $nest_pa_content = @(NEST_PA_CONTENT)
    # Load high fidelity bluetooth modules
    # See https://github.com/EHfive/pulseaudio-modules-bt/issues/33#issuecomment-462842413

    .ifexists module-bluetooth-policy.so
    load-module module-bluetooth-policy
    .endif

    .ifexists module-bluetooth-discover.so
    load-module module-bluetooth-discover a2dp_config="aac_bitrate_mode=5"
    .endif
    | NEST_PA_CONTENT

  file { '/etc/pulse/nest.pa':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $nest_pa_content,
  }
}
