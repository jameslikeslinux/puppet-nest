class nest::gui::media {
  nest::lib::package { [
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

  nest::lib::package { 'media-video/libva-utils':
    ensure => $libva_utils_ensure,
  }
}
