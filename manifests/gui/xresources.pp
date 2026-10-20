# Shared X11 and Xwayland defaults used by the graphical user session.
class nest::gui::xresources {
  file { '/etc/X11/Xresources':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "Xcursor.theme: breeze_cursors\nXcursor.size: ${nest::cursor_size}\nXft.dpi: ${nest::dpi}\n",
  }
}
