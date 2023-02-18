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
    'x11-misc/xwallpaper',

    # For taffybar.hs (Data.List.Utils)
    'dev-haskell/missingh',

    # For taffybar status
    'dev-ruby/concurrent-ruby',
    'sys-fs/inotify-tools',
  ]:
    ensure => installed,
  }

  $gdk_dpi_scale = inline_template('<%= (1.0 / scope.lookupvar("nest::gui_scaling_factor_rounded")).round(3) %>')
  $qt_font_dpi = inline_template('<%= (scope.lookupvar("nest::text_scaling_factor_percent_of_gui") * 96).round %>')
  $xmonad_wrapper_content = epp('nest/xmonad/xmonad.sh.epp', {
    'gdk_dpi_scale' => $gdk_dpi_scale,
    'qt_font_dpi'   => $qt_font_dpi,
  })

  $taffybar_wrapper_content = @("END_WRAPPER")
    #!/bin/bash
    GDK_DPI_SCALE=1 GDK_SCALE=1 exec /usr/bin/taffybar "$@"
    | END_WRAPPER

  file {
    default:
      mode  => '0755',
      owner => 'root',
      group => 'root',
    ;

    '/usr/local/bin/xmonad':
      content => $xmonad_wrapper_content,
    ;

    '/usr/local/bin/taffybar':
      content => $taffybar_wrapper_content,
    ;
  }


  #
  # XXX Cleanup
  #
  package { 'media-gfx/feh':
    ensure => absent,
  }
}
