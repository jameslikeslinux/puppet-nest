# Joy approved bounded informational publication. TLS is enabled only after
# supervised ACME issuance and verified static-only origin acceptance.
class nest::service::joyride_gateway (
  Boolean $tls_enabled = false,
) {
  include 'nest::service::apache'
  include 'apache::mod::ssl'
  include 'apache::mod::rewrite'
  include 'apache::mod::headers'
  include 'apache::mod::proxy_http'

  nest::lib::srv { 'www/joyridedc.com':
    zfs => false,
  }

  $gateway_config = $tls_enabled ? {
    true    => file('nest/app/joyride/production-gateway-apache.conf'),
    default => file('nest/app/joyride/production-acme-apache.conf'),
  }

  apache::custom_config { 'joyride-gateway':
    content        => $gateway_config,
    verify_command => ['/usr/sbin/apache2', '-t'],
    require        => Nest::Lib::Srv['www/joyridedc.com'],
  }
}
