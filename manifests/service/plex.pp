class nest::service::plex {
  nest::lib::package { 'media-tv/plex-media-server':
    ensure => installed,
  }
  ->
  service { 'plexmediaserver':
    enable => true,
  }

  firewalld_service { 'plex':
    ensure => present,
  }
}
