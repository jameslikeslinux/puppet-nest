class nest::role::workstation::terminals {
  nest::lib::package_use { 'x11-terms/rxvt-unicode':
    use => ['256-color', 'alt-font-width', 'secondary-wheel', 'sgrmouse', 'unicode3', '-vanilla', 'xft'],
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

  file {
    default:
      mode  => '0755',
      owner => 'root',
      group => 'root',
    ;

    '/usr/local/bin/alacritty':
      source => 'puppet:///modules/nest/terminals/alacritty',
    ;

    '/usr/local/bin/terminal':
      content => template('nest/terminals/terminal.erb'),
    ;
  }
}
