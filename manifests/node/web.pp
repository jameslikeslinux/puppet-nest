class nest::node::web {
  nest::lib::port_forward { 'gitlab ssh':
    proto           => tcp,
    from_port       => 22,
    to_port         => 2222,
    source_ip4      => '104.156.227.40',
    destination_ip4 => '172.22.0.1',
  }

  nest::lib::reverse_proxy {
    default:
      ip => ['104.156.227.40', '2001:19f0:300:2005::40'],
    ;

    'gitlab.james.tl':
      destination     => '172.22.0.1:8080',
      encoded_slashes => true,
      websockets      => true,
    ;

    'registry.gitlab.james.tl':
      destination => '172.22.0.1:5050',
    ;
  }
}
