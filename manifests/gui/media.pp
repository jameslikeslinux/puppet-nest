class nest::gui::media {
  nest::lib::package { 'media-video/mpv':
    ensure => installed,
  }

  if $facts['profile']['variant'] == 'workstation' {
    nest::lib::package { 'media-sound/playerctl':
      ensure => installed,
    }
  }

  $portage_use = $facts['portage_use'] ? {
    undef   => [],
    default => $facts['portage_use'].split(' '),
  }
  $portage_video_cards = $facts['portage_video_cards'] ? {
    undef   => [],
    default => $facts['portage_video_cards'].split(' '),
  }

  $vaapi_enabled = 'vaapi' in $portage_use
  $libva_utils_ensure = $vaapi_enabled ? {
    true    => installed,
    default => absent,
  }

  nest::lib::package { 'media-video/libva-utils':
    ensure => $libva_utils_ensure,
  }

  $intel_enabled = 'intel' in $portage_video_cards
  $libva_intel_driver_ensure = ($vaapi_enabled and $intel_enabled) ? {
    true    => installed,
    default => absent,
  }

  nest::lib::package { 'media-libs/libva-intel-driver':
    ensure => $libva_intel_driver_ensure,
  }
}
