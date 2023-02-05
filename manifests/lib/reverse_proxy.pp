define nest::lib::reverse_proxy (
  Variant[String, Hash]    $destination,
  Boolean                  $encoded_slashes = false,
  Hash[String, Any]        $extra_params    = {},
  Optional[Nest::IPList]   $ip              = undef,
  Optional[Integer]        $port            = undef,
  Boolean                  $preserve_host   = false,
  String                   $servername      = $name,
  Array[String]            $serveraliases   = [],
  Boolean                  $ssl             = true,
  Optional[Integer]        $timeout         = undef,
  Variant[Boolean, String] $websockets      = false,
) {
  if $encoded_slashes {
    $proxy_pass_keywords = ['nocanon']
    $allow_encoded_slashes = on
  }

  if $timeout {
    $proxy_params = { 'timeout' => $timeout }
  }

  $mappings = $destination ? {
    String  => { '/' => $destination },
    default => $destination,
  }

  $proxy_pass = $mappings.map |$path, $dest| {
    {
      'path'     => $path,
      'url'      => "http://${dest}/",
      'keywords' => $proxy_pass_keywords,
      'params'   => $proxy_params,
    }
  }

  if $websockets {
    include 'apache::mod::proxy_wstunnel'

    $wsdestination = $websockets ? {
      String  => $websockets,
      default => $destination,
    }

    $websocket_rewrites = [{
      'rewrite_cond' => ['%{HTTP:Upgrade} =websocket [NC]'],
      'rewrite_rule' => ["^/(.*)$ ws://${wsdestination}/\$1 [P,L]"],
    }]
  }

  $certbot_exception = @(EOT)
    <Location "/.well-known">
        AllowOverride None
        Require all granted
        ProxyPass !
      </Location>
    | EOT

  nest::lib::virtual_host { $name:
    servername    => $servername,
    serveraliases => $serveraliases,
    ip            => $ip,
    port          => $port,
    ssl           => $ssl,
    zfs_docroot   => false,
    extra_params  => {
      'allow_encoded_slashes' => $allow_encoded_slashes,
      'proxy_pass'            => $proxy_pass,
      'proxy_preserve_host'   => $preserve_host,
      'rewrites'              => $websocket_rewrites,
      'custom_fragment'       => $certbot_exception,
    } + $extra_params,
  }
}
