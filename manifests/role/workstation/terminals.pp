class nest::role::workstation::terminals {
  case $facts['os']['family'] {
    'Gentoo': {
      nest::lib::package_use { 'x11-terms/rxvt-unicode':
        use => [
          '256-color',
          'alt-font-width',
          'fading-colors', # required for 'perl'
          'perl',
          'secondary-wheel',
          'sgrmouse',
          'unicode3',
          '-vanilla',
          'xft',
        ],
      }

      file { '/etc/portage/env/xterm.conf':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => "EXTRA_ECONF='--enable-double-buffer'\n",
      }

      package_env { 'x11-terms/xterm':
        env     => 'xterm.conf',
        require => File['/etc/portage/env/xterm.conf'],
        before  => Package['x11-terms/xterm'],
      }

      package { [
        'gui-apps/foot',
        'x11-terms/alacritty',
        'x11-terms/rxvt-unicode',
        'x11-terms/xterm',
      ]:
        ensure  => installed,
      }

      package { [
        'x11-misc/urxvt-font-size',
        'x11-misc/urxvt-perls',
      ]:
        require => Package['x11-terms/rxvt-unicode'],
      }
    }

    'windows': {
      package { 'alacritty':
        ensure => installed,
      }
      ->
      file {
        # For mouse support and other modern conveniences
        # See: https://github.com/alacritty/alacritty/issues/1663
        default:
          replace => false;
        'C:/Program Files/Alacritty/conpty.dll':
          source => 'https://github.com/wez/wezterm/raw/main/assets/windows/conhost/conpty.dll';
        'C:/Program Files/Alacritty/OpenConsole.exe':
          source => 'https://github.com/wez/wezterm/raw/main/assets/windows/conhost/OpenConsole.exe',
        ;
      }

      # Link to dotfiles
      file {
        default:
          owner => 'james';
        'C:/Users/james/AppData/Roaming/alacritty':
          ensure => directory;
        'C:/Users/james/AppData/Roaming/alacritty/alacritty.toml':
          ensure => link,
          target => 'C:/tools/cygwin/home/james/.config/alacritty/alacritty.toml',
        ;
      }
    }
  }
}
