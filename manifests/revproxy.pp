define nest::revproxy (
  String[1] $destination,
  String[1] $servername                              = $name,
  Array[String[1]] $serveraliases                    = [],
  Optional[Variant[String[1], Array[String[1]]]] $ip = undef,
  Boolean $ssl                                       = true,
) {
  $certbot_exception = @(EOT)
    <Location "/.well-known">
        AllowOverride None
        Require all granted
        ProxyPass !
      </Location>
    | EOT

  nest::vhost { $name:
    servername    => $servername,
    serveraliases => $serveraliases,
    ip            => $ip,
    ssl           => $ssl,
    zfs_docroot   => false,
    extra_params  => {
      'custom_fragment' => $certbot_exception,
      'proxy_pass'      => [
        { 'path' => '/', 'url' => $destination },
      ],
    },
  }
}
