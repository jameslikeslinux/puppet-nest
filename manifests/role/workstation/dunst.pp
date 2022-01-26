class nest::role::workstation::dunst {
  package { 'gnome-base/librsvg':
    ensure => installed,
  }

  package { 'x11-misc/dunst':
    ensure => installed,
  }

  file { [
    '/usr/share/dunst',
    '/usr/share/dunst/icons',
  ]:
    ensure  => directory,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    recurse => true,
    purge   => true,
    force   => true,
  }

  $icon_size   = inline_template("<%= (32 * scope['nest::gui_scaling_factor']).round %>")
  $convert_cmd = @("SCRIPT")
    rsvg-convert -w ${icon_size} -h ${icon_size} -f svg '%' |
    sed 's/${icon_size}pt/${icon_size}px/g' > '%.tmp' &&
    mv '%.tmp' '%'
    | SCRIPT

  ['actions', 'devices', 'status'].each |$category| {
    file {
      default:
        mode  => '0644',
        owner => 'root',
        group => 'root',
      ;

      "/usr/share/dunst/icons/${category}":
        ensure => directory,
      ;

      "/usr/share/dunst/icons/${category}/${icon_size}":
        ensure       => directory,
        source       => "/usr/share/icons/breeze-dark/${category}/22",
        recurse      => true,
        purge        => true,
        backup       => false,
        show_diff    => false,
        validate_cmd => $convert_cmd,
        checksum     => mtime,
        links        => follow,
        max_files    => 10000,
        require      => Package['gnome-base/librsvg'],
      ;

      "/usr/share/dunst/icons/${category}/scaled":
        ensure => link,
        target => "/usr/share/dunst/icons/${category}/${icon_size}",
      ;
    }
  }
}
