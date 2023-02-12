define nest::lib::external_port (
  Stdlib::Port       $port,
  Enum['tcp', 'udp'] $protocol,
  Hash               $params = {},
) {
  firewalld_port {
    default:
      ensure   => present,
      port     => $port,
      protocol => $protocol,
      *        => $params,
    ;

    "${name}-external":
      zone => 'external',
    ;

    "${name}-home":
      zone => 'home',
    ;
  }
}
