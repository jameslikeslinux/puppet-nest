define nest::lib::revproxy (
  String[1] $destination,
  String[1] $servername                              = $name,
  Array[String[1]] $serveraliases                    = [],
  Optional[Variant[String[1], Array[String[1]]]] $ip = undef,
  Optional[Integer] $port                            = undef,
  Boolean $ssl                                       = true,
  Optional[String[1]] $websockets                    = undef,
  Boolean $allow_encoded_slashes                     = false,
  Boolean $preserve_host                             = false,
  Hash[String[1], Any] $extra_params                 = {},
) {
  if $websockets {
    include '::apache::mod::proxy_wstunnel'
  }

  $proxy_pass_match = [
    $websockets ? {
      undef   => [],
      default => {
        'path'         => "^/(${websockets})$",
        'url'          => "ws://${destination}/\$1",
        'reverse_urls' => [],
      },
    },

    $allow_encoded_slashes ? {
      true    => {
        'path'         => '^/(.*)$',
        'url'          => "http://${destination}/\$1",
        'keywords'     => ['nocanon'],
        'reverse_urls' => [],
      },
      default => [],
    },
  ].flatten

  $allow_encoded_slashes_vhost = $allow_encoded_slashes ? {
    true    => on,
    default => undef,
  }

  $certbot_exception = @(EOT)
    <Location "/.well-known">
        AllowOverride None
        Require all granted
        ProxyPass !
      </Location>
    | EOT

  nest::lib::vhost { $name:
    servername    => $servername,
    serveraliases => $serveraliases,
    ip            => $ip,
    port          => $port,
    ssl           => $ssl,
    zfs_docroot   => false,
    extra_params  => {
      'allow_encoded_slashes' => $allow_encoded_slashes_vhost,
      'proxy_preserve_host'   => $preserve_host,
      'proxy_pass_match'      => $proxy_pass_match,
      'proxy_dest'            => "http://${destination}",
      'custom_fragment'       => $certbot_exception,
    } + $extra_params,
  }
}
