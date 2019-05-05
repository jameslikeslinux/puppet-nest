class nest::profile::workstation::media {
  package { 'media-sound/google-play-music-desktop-player-bin':
    ensure => absent,
  }
}
