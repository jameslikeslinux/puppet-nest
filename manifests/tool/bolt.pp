class nest::tool::bolt {
  if $facts['build'] == 'bolt' {
    package { [
      'dev-ruby/bcrypt_pbkdf',
      'dev-ruby/ed25519',
    ]:
      ensure => installed,
    }
    ->
    package { 'bolt':
      install_options => ['--bindir', '/usr/local/bin'],
      provider        => gem,
    }
  } elsif $facts['os']['family'] == 'Gentoo' {
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
        content => file("${settings::ssldir}/certs/ca.pem"),
      ;

      '/etc/puppetlabs/bolt/cert.pem':
        content => file("${settings::ssldir}/certs/bolt.pem"),
      ;

      '/etc/puppetlabs/bolt/key.pem':
        content   => file("${settings::ssldir}/private_keys/bolt.pem"),
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
