class nest::gui::cursor {
  file {
    default:
      ensure    => directory,
      mode      => '0644',
      owner     => 'root',
      group     => 'root',
      recurse   => true,
      force     => true,
      purge     => true,
      backup    => false,
      show_diff => false,
      require   => Class['nest::gui::plasma'],
    ;

    '/usr/share/icons/breeze_cursors':
      source => 'puppet:///modules/nest/cursors/Breeze',
    ;

    '/usr/share/icons/Breeze_Snow':
      source => 'puppet:///modules/nest/cursors/Breeze_Snow',
    ;
  }
}
