class nest::service::wordpress (
  Hash[String, String] $database_passwords,
  Hash[String, Hash] $sites = {},
) {
  $sites.each |$site, $attributes| {
    nest::lib::wordpress { $site:
      database_password => $database_passwords[$site],
      *                 => $attributes,
    }
  }
}
