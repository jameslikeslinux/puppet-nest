class nest::gui::fonts {
  nest::lib::package { 'media-fonts/corefonts':
    ensure => installed,
    use    => 'tahoma',
  }

  nest::lib::package { [
    'media-fonts/fontawesome',
    'media-fonts/liberation-fonts', # primarily for GitHub, tbh
    'media-fonts/noto-emoji',
  ]:
    ensure => installed,
  }

  # The intention here is to express configurations that are related to the
  # system, not necessarily my preference.  In this case, all of my systems are
  # RGB LCDs; however, this could be made configurable in Hiera with some
  # module parameters.  User preference type configurations, like hinting,
  # belong in the user's home directory (~/.config/fontconfig/fonts.conf)
  file { '/etc/fonts/local.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    source  => 'puppet:///modules/nest/fonts/local.conf',

    # fontconfig is pulled in by the portage profile, and all packages
    # depend on the portage profile, so this is just an easy way to
    # establish that relationship.
    require => Nest::Lib::Package['media-fonts/corefonts'],
  }
}
