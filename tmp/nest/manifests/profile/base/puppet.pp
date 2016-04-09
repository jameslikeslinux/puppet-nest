class nest::profile::base::puppet {
  if $::nest::server {
    class { '::puppet':
      unavailable_runmodes => ['cron'],
    }
  } else {
    class { '::puppet':
      unavailable_runmodes => ['cron'],
    }
  }

  package { 'hiera-eyaml':
    ensure =>  installed,
  }

  file { '/etc/eyaml':
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  $eyaml_config = @("EOT")
    ---
    pkcs7_private_key: '${::settings::cakey}'
    pkcs7_public_key: '${::settings::localcacert}'
    | EOT

  file { '/etc/eyaml/config.yaml':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $eyaml_config,
  }
}
