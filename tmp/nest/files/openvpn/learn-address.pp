$delete_changes = [
  "rm *[ipaddr = '${::ip}' or canonical = '${::cn}']",
]

$add_changes = [
  "set 01/ipaddr ${::ip}",
  "set 01/canonical ${::cn}",
]

$changes = $::action ? {
  'add'    => $delete_changes + $add_changes,
  'update' => $delete_changes + $add_changes,
  'delete' => $delete_changes,
}

augeas { "hosts-${::action}-${::ip}":
  incl    => $::hosts_file,
  lens    => 'Hosts.lns',
  context => "/files/${::hosts_file}",
  changes => $changes,
}

exec { '/usr/bin/systemctl reload dnsmasq':
  refreshonly => true,
  subscribe   => Augeas["hosts-${::action}-${::ip}"],
  noop        => $::id != 'root',
}
