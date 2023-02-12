define nest::lib::external_service (
  String $service = $name,
  Hash   $params  = {},
) {
  firewalld_service {
    default:
      ensure  => present,
      service => $service,
      *       => $params,
    ;

    "${name}-external":
      zone => 'external',
    ;

    "${name}-home":
      zone => 'home',
    ;
  }
}
