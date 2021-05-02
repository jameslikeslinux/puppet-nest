class nest::role::workstation::media {
  package { [
    'media-sound/playerctl',
    'media-video/libva-utils',
  ]:
    ensure => installed,
  }
}
