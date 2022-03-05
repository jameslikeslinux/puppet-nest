class nest::tool::pdk {
  if $facts['build'] == 'pdk' {
    $pdk_version        = '2.4.0'
    $ruby_minor_version = $facts['ruby']['version'].regsubst('^(\d+\.\d+).*', '\1')

    package { 'pdk':
      ensure          => $pdk_version,
      install_options => ['--bindir', '/usr/local/bin'],
      provider        => gem,
    }
    ->
    file_line { 'pdk-gem-path':
      path  => "/usr/local/lib64/ruby/gems/${ruby_minor_version}.0/gems/pdk-${pdk_version}/lib/pdk/util/ruby_version.rb",
      line  => '[bundler_basedir]',
      match => 'absolute_path.*join.*bundler_basedir',
    }

    # Install PDK runtime dependencies
    package { [
      'dev-ruby/bcrypt_pbkdf',
      'dev-ruby/ed25519',
    ]:
      ensure => installed,
    }
    ->
    package { [
      "puppet-module-posix-default-r2.6",
      "puppet-module-posix-default-r2.7",
      "puppet-module-posix-dev-r2.6",
      "puppet-module-posix-dev-r2.7",
      "puppet-module-posix-system-r2.6",
      "puppet-module-posix-system-r2.7",
    ]:
      ensure   => installed,
      provider => gem,
    }
  } elsif $facts['os']['family'] == 'Gentoo' {
    file { '/usr/local/bin/pdk':
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      content => epp('nest/scripts/pdk.sh.epp'),
    }
  }
}
