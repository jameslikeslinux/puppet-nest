class nest::tool::bolt {
  if $facts['build'] == 'bolt' {
    $bolt_version       = '5.6.0'
    $ruby_minor_version = $facts['ruby']['version'].regsubst('^(\d+\.\d+).*', '\1')
    $bolt_gem_dir       = "/usr/local/lib64/ruby/gems/${ruby_minor_version}.0/gems/openbolt-${bolt_version}"

    package {
      default:
        install_options => ['--bindir', '/usr/local/bin'],
        provider        => gem,
      ;
      ['ed25519', 'bcrypt_pbkdf', 'toml-rb']:
        ensure => installed,
      ;
      'openbolt':
        ensure => $bolt_version,
      ;
    }
    ->
    file {
      '/usr/local/bin':
        purge   => true,
        recurse => true;
      '/usr/local/bin/bolt':
        ensure => file;
    }

    # For vaultwarden token hashing
    nest::lib::package { 'app-crypt/argon2':
      ensure => installed,
    }

    # Podman's --format '{{json .}}' emits one JSON object per line.
    # OpenBolt 5.6.0 handles a single minified object but not multiple objects;
    # inherit Docker's line-oriented parser, as required by real transport smoke.
    exec { 'bolt-fix-podman-transport':
      command => "/bin/sed -i '/^\\s*private def extract_json/,/^\\s*end/d' ${bolt_gem_dir}/lib/bolt/transport/podman/connection.rb",
      onlyif  => "/bin/grep -q '^\\s*private def extract_json' ${bolt_gem_dir}/lib/bolt/transport/podman/connection.rb",
      require => Package['openbolt'],
    }
  } else {
    require nest::base::puppet

    $config_group = $facts['os']['family'] ? {
      'Darwin' => 'wheel',
      default  => 'root',
    }

    file {
      default:
        mode  => '0644',
        owner => 'root',
        group => $config_group,
      ;

      '/etc/puppetlabs/bolt':
        ensure => directory,
      ;

      # The existing internal HTTPS ingress terminates TLS with Eyrie trust.
      # It exposes read-only queries; legacy mTLS credentials are not used.
      # Leave the old files untouched for offline rollback.
      '/etc/puppetlabs/bolt/ingress-ca.pem':
        source => 'puppet:///modules/nest/certs/eyrie.crt',
      ;

      '/etc/puppetlabs/bolt/bolt-defaults.yaml':
        content   => epp('nest/puppet/bolt-defaults.yaml.epp', {
          puppetdb_server_url => 'https://puppetdb.eyrie:443',
          puppetdb_cacert     => '/etc/puppetlabs/bolt/ingress-ca.pem',
        }),
      ;
    }

    case $facts['os']['family'] {
      'Gentoo': {
        file { '/usr/local/bin/bolt':
          mode    => '0755',
          content => epp('nest/scripts/bolt.sh.epp', {
            'puppetcore_gem_source' => $nest::base::puppet::puppetcore_gem_source,
          }),
        }
      }

      'Darwin': {
        package { 'openvox8-openbolt':
          ensure  => installed,
          require => Class['nest::base::puppet'],
        }
      }
    }
  }
}
