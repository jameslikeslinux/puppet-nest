class nest::profile::workstation::fonts {
  nest::portage::package_use { 'media-fonts/corefonts':
    use => 'tahoma',
  }

  package { [
    'media-fonts/corefonts',
    'media-fonts/fontawesome',
    'media-fonts/liberation-fonts', # primarily for GitHub, tbh
  ]:
    ensure => installed,
  }

  file { '/etc/fonts/local.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    source  => 'puppet:///modules/nest/fonts/local.conf',

    # fontconfig is pulled in by the portage profile, and all packages
    # depend on the portage profile, so this is just an easy way to
    # establish that relationship.
    require => Package['media-fonts/corefonts'],
  }

  file { '/etc/fonts/conf.d/10-hinting-slight.conf':
    ensure  => absent,
    require => Package['media-fonts/corefonts'],
  }
}
