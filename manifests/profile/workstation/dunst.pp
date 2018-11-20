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

  $icon_size = inline_template("<%= (32 * scope['nest::gui_scaling_factor']).round %>")

  ['actions', 'devices', 'status'].each |$category| {
    file { "/usr/share/dunst/icons/${category}":
      ensure       => directory,
      mode         => '0644',
      owner        => 'root',
      group        => 'root',
      source       => "/usr/share/icons/breeze-dark/${category}/22",
      recurse      => true,
      purge        => true,
      backup       => false,
      show_diff    => false,
      validate_cmd => "rsvg-convert -w ${icon_size} -h ${icon_size} -f svg '%' | sed 's/${icon_size}pt/${icon_size}px/g' > '%.tmp' && mv '%.tmp' '%'",
      checksum     => mtime,
      links        => follow,
      require      => Package['gnome-base/librsvg'],
    }
  }
}
