class nest::tool::bolt (
  String            $cert,
  Sensitive[String] $key,
  Optional[String]  $ca = undef,
) {
  if $facts['build'] == 'bolt' {
    $ruby_minor_version = $facts['ruby']['version'].regsubst('^(\d+\.\d+).*', '\1')

    # Gem conflicts with system gems who cares
    file { "/usr/lib64/ruby/gems/${ruby_minor_version}.0":
      ensure => absent,
      force  => true,
    }
    ->
    package { ['bolt', 'ed25519', 'bcrypt_pbkdf', 'toml-rb']:
      install_options => ['--bindir', '/usr/local/bin'],
      provider        => gem,
    }

    # For vaultwarden token hashing
    nest::lib::package { 'app-crypt/argon2':
      ensure => installed,
    }
  } elsif $facts['os']['family'] == 'Gentoo' {
    if $ca {
      $ca_content = $ca
    } else {
      $ca_content = file("${settings::ssldir}/certs/ca.pem")
    }

    file {
      default:
        mode  => '0644',
        owner => 'root',
        group => 'root',
      ;

      '/etc/puppetlabs/bolt':
        ensure => directory,
      ;

      '/etc/puppetlabs/bolt/ca.pem':
        content => $ca_content,
      ;

      '/etc/puppetlabs/bolt/cert.pem':
        content => $cert,
      ;

      '/etc/puppetlabs/bolt/key.pem':
        content   => $key,
        show_diff => false,
      ;

      '/etc/puppetlabs/bolt/bolt-defaults.yaml':
        content   => epp('nest/puppet/bolt-defaults.yaml.epp', {
          puppetdb_server_url => 'https://puppetdb.nest:8081',
          puppetdb_cacert     => '/etc/puppetlabs/bolt/ca.pem',
          puppetdb_cert       => '/etc/puppetlabs/bolt/cert.pem',
          puppetdb_key        => '/etc/puppetlabs/bolt/key.pem',
        }),
      ;

      '/usr/local/bin/bolt':
        mode    => '0755',
        content => epp('nest/scripts/bolt.sh.epp'),
      ;
    }
  }
}
