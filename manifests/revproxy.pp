define nest::revproxy (
  String[1] $destination,
  String[1] $servername                              = $name,
  Array[String[1]] $serveraliases                    = [],
  Optional[Variant[String[1], Array[String[1]]]] $ip = undef,
  Boolean $ssl                                       = true,
  Optional[String[1]] $websockets                    = undef,
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

  $proxy_pass = [
    $websockets ? {
      undef   => [],
      default => { 'path' => $websockets, 'url' => "${wsdestination}${websockets}" }
    },

    { 'path' => '/', 'url' => $destination },
  ].flatten

  nest::vhost { $name:
    servername    => $servername,
    serveraliases => $serveraliases,
    ip            => $ip,
    ssl           => $ssl,
    zfs_docroot   => false,
    extra_params  => {
      'custom_fragment' => $certbot_exception,
      'proxy_pass'      => $proxy_pass,
    },
  }
}
