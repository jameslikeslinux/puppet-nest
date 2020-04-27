class nest::role::workstation::media {
  package { 'media-video/libva-utils':
    ensure => installed,
  }
}
