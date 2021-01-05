class nest::role::workstation::xmonad {
  nest::lib::package_use {
    'x11-misc/rofi':
      use => 'windowmode',
    ;

    'media-gfx/feh':
      use => 'xinerama',
    ;
  }

  nest::lib::repo { 'haskell':
    url      => 'https://gitlab.james.tl/nest/gentoo/haskell.git',
    unstable => true,
  }

  # Bootstrap GHC on architectures without up-to-date binaries
  if $facts['architecture'] != 'amd64' {
    exec { 'install-binary-ghc':
      command     => '/usr/bin/emerge -v1 "=dev-lang/ghc-8.6.5::haskell"',
      creates     => '/usr/bin/ghc',
      environment => 'USE=binary -ghcbootstrap',
      timeout     => 0,
      require     => Class['nest::lib::repos'],
    }
    ~>
    exec { 'bootstrap-ghc':
      command     => '/usr/bin/emerge -v1 dev-lang/ghc::haskell',
      refreshonly => true,
      timeout     => 0,
      before      => Package['x11-wm/xmonad'],
    }
  }

  # Let xmonad serve as the synchronization point for the first Haskell package
  package { 'x11-wm/xmonad':
    ensure => installed,
  }
  ->
  package { [
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
