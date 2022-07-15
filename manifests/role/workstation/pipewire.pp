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

    'systemd-enable-wireplumber':
      command => '/bin/systemctl --user --global enable wireplumber.service',
      creates => '/etc/systemd/user/pipewire.service.wants/wireplumber.service',
    ;
  }

  nest::lib::package { 'media-sound/pulseaudio':
    ensure => installed,
    world  => false,
  }
  ->
  file_line { 'pulse-client.conf-disable-autospawn':
    path  => '/etc/pulse/client.conf',
    match => '^(; )?autospawn = ',
    line  => 'autospawn = no',
  }

  # For increasing pipewire scheduling priority
  nest::lib::package { 'sys-auth/rtkit':
    ensure => installed,
  }

  # Fix stuttering audio in VMware
  # See: https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/469
  if $facts['virtual'] == 'vmware' {
    file {
      default:
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        require => Package['media-video/pipewire'],
      ;

      '/etc/pipewire':
        ensure  => directory,
      ;

      '/etc/pipewire/pipewire.conf':
        replace => false,
        source  => '/usr/share/pipewire/pipewire.conf',
      ;
    }
    ->
    file_line { 'pipewire-default-clock-rate':
      path  => '/etc/pipewire/pipewire.conf',
      after => '^\s*vm\.overrides\s*=\s*{',
      line  => '        default.clock.rate        = 44100',
      match => '^\s*default\.clock\.rate\s*=',
    }

    file_line {
      default:
        path               => '/etc/wireplumber/main.lua.d/50-alsa-config.lua',
        append_on_no_match => false,
        require            => Package['media-video/pipewire'],
      ;

      'alsa-period-size':
        line  => '      ["api.alsa.period-size"]     = 256,',
        match => '^\s*(--)?\["api\.alsa\.period-size"\]\s*=',
      ;

      'alsa-headroom':
        line  => '      ["api.alsa.headroom"]        = 8192,',
        match => '^\s*(--)?\["api\.alsa\.headroom"\]\s*=',
      ;
    }
  }
}
