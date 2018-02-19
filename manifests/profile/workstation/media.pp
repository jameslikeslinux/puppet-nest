class nest::profile::workstation::media {
  package { 'media-sound/google-play-music-desktop-player-bin':
    ensure => installed,
  }

  $gpmdp_wrapper = @(GPMDP_WRAPPER)
    #!/bin/bash
    exec "/usr/share/google-play-music-desktop-player/Google Play Music Desktop Player" --disable-smooth-scrolling "$@"
    | GPMDP_WRAPPER

  file { '/usr/bin/google-play-music-desktop-player':
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => $gpmdp_wrapper,
  }

  nest::portage::package_use { [
    'media-sound/cantata',
    'media-sound/mpd',
  ]:
    ensure => absent,
    use    => [],
  }

  package { [
    'media-sound/cantata',
    'media-sound/mpc',
    'media-sound/mpd',
    'media-sound/mpdas',
  ]:
    ensure => absent,
  }

  file { '/home/james/.config/mpd':
    ensure  => absent,
    recurse => true,
    force   => true,
  }

  file { '/home/james/.mpdasrc':
    ensure => absent,
  }
}
