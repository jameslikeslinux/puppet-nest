class nest::role::workstation::xmonad {
  nest::lib::package_use {
    'x11-misc/xmobar':
      use => 'xft',
    ;

    'x11-misc/rofi':
      use => 'windowmode',
    ;

    'media-gfx/feh':
      use => 'xinerama',
    ;
  }

  package { [
    'x11-wm/xmonad',
    'x11-wm/xmonad-contrib',
    'x11-misc/picom',
    'x11-misc/rofi',
    'x11-misc/taffybar',
    'dev-haskell/missingh',
    'media-gfx/feh',

    # For taffybar status
    'dev-ruby/concurrent-ruby',
    'net-wireless/iw',
    'sys-fs/inotify-tools',
  ]:
    ensure => installed,
  }

  # Replaced by picom
  package { 'x11-misc/compton':
    ensure => absent,
    before => Package['x11-misc/picom'],
  }

  # Gtk scaling for Taffybar doesn't work well
  exec { 'move-taffybar-binary':
    command => '/bin/mv -f /usr/bin/taffybar /usr/bin/taffybar.real',
    unless  => '/bin/grep \'^#!/bin/bash$\' /usr/bin/taffybar',
    require => Package['x11-misc/taffybar'],
  }

  $taffybar_wrapper_content = @("END_WRAPPER")
    #!/bin/bash
    GDK_DPI_SCALE=${::nest::text_scaling_factor} GDK_SCALE=1 exec /usr/bin/taffybar.real "$@"
    | END_WRAPPER

  file { '/usr/bin/taffybar':
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => $taffybar_wrapper_content,
    require => Exec['move-taffybar-binary'],
  }
}
