class nest::role::workstation::dunst {
  package { 'gnome-base/librsvg':
    ensure => installed,
  }

  package { 'x11-misc/dunst':
    ensure => installed,
  }

  File {
    mode      => '0644',
    owner     => 'root',
    group     => 'root',
    purge     => true,
    recurse   => true,
    force     => true,
    max_files => 10000,
  }

  file { [
    '/usr/share/dunst',
    '/usr/share/dunst/icons',
  ]:
    ensure => directory,
  }

  $icon_size   = 32
  $convert_cmd = @("SCRIPT")
    rsvg-convert -w ${icon_size} -h ${icon_size} -f svg '%' |
    sed 's/${icon_size}pt/${icon_size}px/g' > '%.tmp' &&
    mv '%.tmp' '%'
    | SCRIPT

  ['actions', 'devices', 'status'].each |$category| {
    file {
      "/usr/share/dunst/icons/${category}":
        ensure => directory,
      ;

      "/usr/share/dunst/icons/${category}/${icon_size}":
        ensure       => directory,
        source       => "/usr/share/icons/breeze-dark/${category}/22",
        backup       => false,
        show_diff    => false,
        validate_cmd => $convert_cmd,
        checksum     => mtime,
        links        => follow,
        require      => Package['gnome-base/librsvg'],
      ;

      "/usr/share/dunst/icons/${category}/scaled":
        ensure  => link,
        target  => "/usr/share/dunst/icons/${category}/${icon_size}",
        recurse => false,
      ;
    }
  }
}
