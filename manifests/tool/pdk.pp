class nest::tool::pdk {
  if $facts['build'] == 'pdk' {
    $pdk_version        = '2.3.0'
    $ruby_minor_version = $facts['ruby']['version'].regsubst('^(\d+\.\d+).*', '\1')

    package { 'pdk':
      ensure          => $pdk_version,
      install_options => ['--bindir', '/usr/local/bin'],
      provider        => gem,
      require         => File['/usr/local/bin/pdk'],  # overwrites wrapper
    }
    ->
    file_line { 'pdk-gem-path':
      path  => "/usr/local/lib64/ruby/gems/${ruby_minor_version}.0/gems/pdk-${pdk_version}/lib/pdk/util/ruby_version.rb",
      line  => '[bundler_basedir]',
      match => 'absolute_path.*join.*bundler_basedir',
    }

    # Install PDK runtime dependencies, working around
    # https://github.com/sickill/rainbow/issues/69 in the process.
    exec { 'gem-install-rake':
      command => '/usr/bin/gem install rake --bindir /usr/local/bin',
      creates => '/usr/local/bin/rake',
    }
    ->
    package { [
      "puppet-module-posix-default-r${ruby_minor_version}",
      "puppet-module-posix-dev-r${ruby_minor_version}",
      "puppet-module-posix-system-r${ruby_minor_version}",
    ]:
      ensure   => installed,
      provider => gem,
    }

    package { 'json':
      ensure   => '2.1.0',
      provider => gem,
    }
  } else {
    file { '/usr/local/bin/pdk':
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      content => epp('nest/scripts/pdk.sh.epp'),
    }
  }
}
