class nest::profile::workstation::cursor {
  file {
    default:
      mode    => '0644',
      owner   => 'root',
      group   => 'root';

    '/etc/X11/Xresources':
      content => "Xcursor.size: ${::nest::cursor_size}\n";

    '/etc/plasma/startup/10-cursor.sh':
      content => "export XCURSOR_SIZE=${::nest::cursor_size}\n";

    '/usr/share/icons/breeze_cursors':
      ensure  => directory,
      source  => 'puppet:///modules/nest/cursors/Breeze',
      recurse => true,
      purge   => true,
      backup  => false;

    '/usr/share/icons/Breeze_Snow':
      ensure  => directory,
      source  => 'puppet:///modules/nest/cursors/Breeze_Snow',
      recurse => true,
      purge   => true,
      backup  => false;
  }

  file_line { 'sddm-load-xresources':
    path => '/usr/share/sddm/scripts/Xsetup',
    line => 'xrdb -merge /etc/X11/Xresources',
  }
}
