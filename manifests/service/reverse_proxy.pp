class nest::service::reverse_proxy (
  Hash[String, Hash] $hosts = {},
) {
  $hosts.each |$host, $attributes| {
    nest::lib::reverse_proxy { $host:
      * => $attributes,
    }
  }
}
