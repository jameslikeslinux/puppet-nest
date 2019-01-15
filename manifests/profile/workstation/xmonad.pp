class nest::profile::workstation::xmonad {
  nest::portage::package_use { 'x11-misc/xmobar':
    use => 'xft',
  }

  nest::portage::package_use { 'x11-misc/rofi':
    use => 'windowmode',
  }

  package { [
    'x11-wm/xmonad',
    'x11-wm/xmonad-contrib',
    'x11-misc/compton',
    'x11-misc/rofi',
    'x11-misc/taffybar',
    'dev-haskell/missingh',
    'media-gfx/feh',
    'net-wireless/iw',  # for taffybar status
  ]:
    ensure => installed,
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
