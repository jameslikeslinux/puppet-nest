class nest::role::workstation::media {
  package { [
    'media-sound/playerctl',
    'media-video/mpv',
  ]:
    ensure => installed,
  }

  if $facts['profile']['platform'] == 'haswell' {
    package { 'media-video/libva-utils':
      ensure => installed,
    }
  }
}
