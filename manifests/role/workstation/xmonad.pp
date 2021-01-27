class nest::role::workstation::xmonad {
  nest::lib::repo { 'haskell':
    url      => 'https://gitlab.james.tl/nest/gentoo/haskell.git',
    unstable => true,
  }

  nest::lib::package_use {
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
    'media-gfx/feh',

    # For taffybar.hs (Data.List.Utils)
    'dev-haskell/missingh',

    # For taffybar status
    'dev-ruby/concurrent-ruby',
    'net-wireless/iw',
    'sys-fs/inotify-tools',
  ]:
    ensure => installed,
  }

  $taffybar_wrapper_content = @("END_WRAPPER")
    #!/bin/bash
    GDK_DPI_SCALE=${::nest::text_scaling_factor} GDK_SCALE=1 exec /usr/bin/taffybar "$@"
    | END_WRAPPER

  file { '/usr/local/bin/taffybar':
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => $taffybar_wrapper_content,
  }
}
