class nest::profile::workstation::dunst {
  package { 'gnome-base/librsvg':
    ensure => installed,
  }

  package { 'x11-misc/dunst':
    ensure => installed,
  }

  file { '/usr/share/dunst/icons':
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  ['actions', 'devices', 'status'].each |$category| {
    file { "/usr/share/dunst/icons/${category}":
      ensure       => directory,
      mode         => '0644',
      owner        => 'root',
      group        => 'root',
      source       => "/usr/share/icons/breeze-dark/${category}/22",
      recurse      => true,
      purge        => true,
      validate_cmd => 'rsvg-convert -w 96 -h 96 -f svg \'%\' | sed \'s/96pt/96px/g\' > \'%.tmp\' && mv \'%.tmp\' \'%\'',
      checksum     => mtime,
      links        => follow,
      require      => Package['gnome-base/librsvg'],
    }
  }
}
