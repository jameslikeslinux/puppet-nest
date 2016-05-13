class nest::profile::workstation::cursor {
  exec { 'remove-upstream-breeze-cursor':
    command => '/bin/rm -rf /usr/share/icons/breeze_cursors',
    onlyif  => '/bin/grep "KDE Plasma Cursor Theme" /usr/share/icons/breeze_cursors/index.theme',
  }

  archive { 'breeze-serie-default-2.0.0':
    url              => 'https://thestaticvoid.com/dist/breeze-serie/2.0.0/Breeze.tgz',
    digest_string    => 'b03fe99c13a2f136904833718bdc34950a2a31d9c7e907355b7be61f5a012d09',
    digest_type      => 'sha256',
    target           => '/usr/share/icons/breeze_cursors',
    root_dir         => '',
    strip_components => 1,
  }
}
