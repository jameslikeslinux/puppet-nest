class nest::service::gateway (
  Hash[String, Hash] $port_forwards = {},
) {
  $port_forwards.each |$service, $attributes| {
    nest::lib::port_forward { $service:
      * => $attributes,
    }
  }
}
