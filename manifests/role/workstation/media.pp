class nest::role::workstation::media {
  package { [
    'media-sound/playerctl',
    'media-video/mpv',
  ]:
    ensure => installed,
  }

  if 'vaapi' in $facts['portage_use'].split(' ') {
    $libva_utils_ensure = installed
  } else {
    $libva_utils_ensure = absent
  }

  package { 'media-video/libva-utils':
    ensure => $libva_utils_ensure,
  }
}
