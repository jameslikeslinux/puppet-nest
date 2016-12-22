class nest::profile::workstation::cursor {
  file {
    default:
      ensure    => directory,
      mode      => '0644',
      owner     => 'root',
      group     => 'root',
      recurse   => true,
      purge     => true,
      backup    => false,
      show_diff => false;

    '/usr/share/icons/breeze_cursors':
      source => 'puppet:///modules/nest/cursors/Breeze';

    '/usr/share/icons/Breeze_Snow':
      source => 'puppet:///modules/nest/cursors/Breeze_Snow';
  }

  file { '/usr/share/icons/default':
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  file {
    default:
      mode    => '0644',
      owner   => 'root',
      group   => 'root';

    '/etc/X11/Xresources':
      content => "Xcursor.size: ${::nest::cursor_size}\n";

    '/etc/plasma/startup/10-cursor.sh':
      content => "export XCURSOR_SIZE=${::nest::cursor_size}\n";

    # There seems to be a bug in Plasma 5.8.4 where it doesn't set the
    # right cursor theme for title bars.  This is an ugly work-around.
    # See: https://wiki.archlinux.org/index.php/Cursor_themes#XDG_specification
    '/usr/share/icons/default/index.theme':
      content => "[icon theme]\nInherits=breeze_cursors\n";
  }

  file_line { 'sddm-load-xresources':
    path => '/usr/share/sddm/scripts/Xsetup',
    line => 'xrdb -merge /etc/X11/Xresources',
  }
}
