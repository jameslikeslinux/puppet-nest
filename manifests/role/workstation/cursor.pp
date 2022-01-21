class nest::role::workstation::cursor {
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
      source => 'puppet:///modules/nest/cursors/Breeze',
    ;

    '/usr/share/icons/Breeze_Snow':
      source => 'puppet:///modules/nest/cursors/Breeze_Snow',
    ;
  }
}
