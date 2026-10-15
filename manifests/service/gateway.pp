class nest::service::gateway (
  Hash[String, Hash] $port_forwards = {},
) {
  include 'nest::service::apache'

  # Unconfigured hostnames must not fall through to another public service.
  apache::custom_config { 'strict-host-check':
    content => "StrictHostCheck On\n",
  }

  $port_forwards.each |$service, $attributes| {
    nest::lib::port_forward { $service:
      * => $attributes,
    }
  }
}
