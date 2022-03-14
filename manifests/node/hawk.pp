class nest::node::hawk {
  firewalld_direct_chain { 'LIBVIRT_FWX':
    inet_protocol => ipv4,
    table         => filter,
  }
  ->
  firewalld_direct_rule { 'cd4pe':
    inet_protocol => ipv4,
    table         => filter,
    chain         => 'LIBVIRT_FWX', # applies before LIBVIRT_FWI
    priority      => 0,
    args          => '-d 10.81.40.11 -p tcp --dport 8000 -j ACCEPT',
  }
}
