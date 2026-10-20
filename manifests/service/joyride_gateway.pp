# Dormant production candidate. No host data includes this class. Activation
# requires Joy's separate approval, supervised certificates and origin acceptance.
class nest::service::joyride_gateway {
  include 'nest::service::apache'
  include 'apache::mod::ssl'
  include 'apache::mod::rewrite'
  include 'apache::mod::headers'
  include 'apache::mod::proxy_http'

  nest::lib::srv { 'www/joyridedc.com':
    zfs => false,
  }

  apache::custom_config { 'joyride-gateway':
    content        => file('nest/app/joyride/production-gateway-apache.conf'),
    verify_command => ['/usr/sbin/apache2', '-t'],
  }
}
