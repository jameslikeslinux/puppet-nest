class nest::service::gateway (
  Hash[String, Hash] $port_forwards = {},
  Boolean            $http          = false,
) {
  if $http {
    include 'nest::service::apache'

    # Unconfigured hostnames must not fall through to another public service.
    apache::custom_config { 'strict-host-check':
      content        => "StrictHostCheck On\n",
      verify_command => ['/usr/sbin/apache2', '-t'],
    }
  }

  $port_forwards.each |$service, $attributes| {
    nest::lib::port_forward { $service:
      * => $attributes,
    }
  }
}
