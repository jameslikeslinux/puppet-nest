define nest::lib::wlan (
  Enum[absent, present]       $ensure     = present,
  String                      $ssid       = $name,
  Enum[eap, psk]              $security   = psk,
  Optional[Sensitive[String]] $passphrase = undef,
) {
  $extension = $security ? {
    'eap'   => '8021x',
    default => $security,
  }
  $file = "/var/lib/iwd/${ssid}.${extension}"

  case $ensure {
    'present': {
      if $security != psk {
        fail("Security method '${security}' not handled yet")
      }

      file { $file:
        ensure => file,
        mode   => '0600',
        owner  => 'root',
        group  => 'root',
      }
      ->
      ini_setting { "${name}-passphrase":
        ensure    => present,
        path      => $file,
        section   => 'Security',
        setting   => 'Passphrase',
        value     => $passphrase,
        show_diff => false,
      }
    }

    'absent': {
      file { $file:
        ensure => absent,
      }
    }
  }
}
