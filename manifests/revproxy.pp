define nest::revproxy (
  String[1] $destination,
  String[1] $servername                              = $name,
  Array[String[1]] $serveraliases                    = [],
  Optional[Variant[String[1], Array[String[1]]]] $ip = undef,
  Optional[Integer] $port                            = undef,
  Boolean $ssl                                       = true,
  Optional[String[1]] $websockets                    = undef,
  Array[String[1]] $websockets_exceptions            = [],
  Boolean $preserve_host                             = false,
  Hash[String[1], Any] $extra_params                 = {},
) {
  $certbot_exception = @(EOT)
    <Location "/.well-known">
        AllowOverride None
        Require all granted
        ProxyPass !
      </Location>
    | EOT

  if $websockets {
    include '::apache::mod::proxy_wstunnel'
  }

  $wsdestination = $destination.regsubst('^http', 'ws').regsubst('/$', '')
  $wsexceptiondest = $destination.regsubst('/$', '')

  $proxy_params = $destination ? {
    /(localhost|127\.0\.0\.1)/ => {},
    default                    => { 'keepalive' => 'On' },
  }

  $websockets_exceptions_proxy_pass = $websockets_exceptions.map |$ex| {
    { 'path' => $ex, 'url' => "${wsexceptiondest}${ex}", 'params' => $proxy_params }
  }

  $proxy_pass = [
    $websockets_exceptions_proxy_pass,

    $websockets ? {
      undef   => [],
      default => { 'path' => $websockets, 'url' => "${wsdestination}${websockets}", 'params' => $proxy_params },
    },

    $websockets ? {
      '/'     => [],
      default => { 'path' => '/', 'url' => $destination, 'params' => $proxy_params },
    }
  ].flatten

  nest::vhost { $name:
    servername    => $servername,
    serveraliases => $serveraliases,
    ip            => $ip,
    port          => $port,
    ssl           => $ssl,
    zfs_docroot   => false,
    extra_params  => {
      'custom_fragment'     => $certbot_exception,
      'proxy_pass'          => $proxy_pass,
      'proxy_preserve_host' => $preserve_host,
    } + $extra_params,
  }
}
