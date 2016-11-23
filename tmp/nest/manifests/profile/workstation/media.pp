class nest::profile::workstation::media {
  nest::portage::package_use { 'media-sound/cantata':
    use => ['-cdda', '-kde'],
  }

  nest::portage::package_use { 'media-sound/mpd':
    use => 'libmpdclient',
  }

  package { [
    'media-sound/cantata',
    'media-sound/google-play-music-desktop-player-bin',
    'media-sound/mpc',
    'media-sound/mpd',
    'media-sound/mpdas',
  ]:
    ensure => installed,
  }

  case "${::trusted['certname']}.nest" {
    $::nest::nestfs_hostname: {
      $mpdconf_content = @(EOT)
        music_directory    "/nest/music"
        playlist_directory "/nest/music/playlists"
        db_file            "~/.config/mpd/database"
        state_file         "~/.config/mpd/state"
        log_file           "syslog"
        replaygain         "auto"

        audio_output {
            type "pulse"
            name "PulseAudio"
        }
        | EOT
    }

    default: {
      $mpdconf_content = @("EOT")
        music_directory    "/nest/music"
        playlist_directory "/nest/music/playlists"
        state_file         "~/.config/mpd/state"
        log_file           "syslog"
        replaygain         "auto"

        audio_output {
            type "pulse"
            name "PulseAudio"
        }

        database {
            plugin "proxy"
            host "${::nest::nestfs_hostname}"
        }
        | EOT
    }
  }

  exec { '/bin/mkdir -p /home/james/.config/mpd':
    unless  => '/usr/bin/test -d /home/james/.config/mpd',
    require => File['/home/james'],
  }

  file { '/home/james/.config/mpd':
    ensure  => directory,
    mode    => '0755',
    owner   => 'james',
    group   => 'users',
    require => Exec['/bin/mkdir -p /home/james/.config/mpd'],
  }

  file { '/home/james/.config/mpd/mpd.conf':
    mode    => '0644',
    owner   => 'james',
    group   => 'users',
    content => $mpdconf_content,
  }

  $mpdasrc_content = @("EOT")
    username = MrStaticVoid
    password = ${::nest::lastfm_pw_hash}
    | EOT

  file { '/home/james/.mpdasrc':
    mode      => '0600',
    owner     => 'james',
    group     => 'users',
    content   => $mpdasrc_content,
    show_diff => false,
  }
}
