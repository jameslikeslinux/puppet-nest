class nest::tool::bolt {
  if $facts['build'] == 'bolt' {
    package { 'bolt':
      install_options => ['--bindir', '/usr/local/bin'],
      provider        => gem,
    }
  } elsif $facts['os']['family'] == 'Gentoo' {
    $ssldir = '/etc/puppetlabs/puppet/ssl'

    file {
      default:
        mode  => '0644',
        owner => 'root',
        group => 'root',
      ;

      '/etc/puppetlabs/bolt':
        ensure => directory,
      ;

      '/etc/puppetlabs/bolt/bolt-defaults.yaml':
        content   => epp('nest/puppet/bolt-defaults.yaml.epp', {
          puppetdb_server_url => 'https://puppetdb.nest:8081',
          puppetdb_cacert     => "${ssldir}/certs/ca.pem",
          puppetdb_cert       => "${ssldir}/certs/${trusted['certname']}.pem",
          puppetdb_key        => "${ssldir}/private_keys/${trusted['certname']}.pem",
        }),
        show_diff => false,
      ;

      '/usr/local/bin/bolt':
        mode    => '0755',
        content => epp('nest/scripts/bolt.sh.epp'),
      ;
    }
  }
}
