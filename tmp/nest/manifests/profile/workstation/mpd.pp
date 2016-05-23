class nest::profile::workstation::mpd {
  nest::portage::package_use { 'media-sound/cantata':
    use => ['-cdda', '-kde'],
  }

  package { [
    'media-sound/cantata',
    'media-sound/mpd',
    'media-sound/mpdas',
  ]:
    ensure => installed,
  }

  $mpdasrc_content = @("EOT")
    username = MrStaticVoid
    password = ${::nest::lastfm_pw_hash}
    | EOT

  file { '/home/james/.mpdasrc':
    mode    => '0600',
    owner   => 'james',
    group   => 'users',
    content => $mpdasrc,
  }
}
