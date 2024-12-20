class nest::tool::pdk {
  if $facts['build'] == 'pdk' {
    $pdk_version        = '3.4.0'
    $ruby_minor_version = $facts['ruby']['version'].regsubst('^(\d+\.\d+).*', '\1')
    $pdk_gem_dir        = "/usr/local/lib64/ruby/gems/${ruby_minor_version}.0/gems/pdk-${pdk_version}"

    Package {
      install_options => ['--bindir', '/usr/local/bin'],
      provider        => gem,
    }

    # Required by pdk-templates-3.4.0 but not specified by the gem
    package { 'puppet_litmus':
      ensure => installed,
    }
    ->
    package { 'pdk':
      ensure => $pdk_version,
    }
    ->
    file_line {
      # The default path is bundler_basedir/../../.. which doesn't work
      'pdk-gem-path':
        path  => "${pdk_gem_dir}/lib/pdk/util/ruby_version.rb",
        line  => '[bundler_basedir]',
        match => 'absolute_path.*join.*bundler_basedir',
      ;

      # Yes, install missing gems into the container image
      'pdk-bundler-install-remote':
        path  => "${pdk_gem_dir}/lib/pdk/util/bundler.rb",
        line  => 'update_lock!(only: { json: nil }, local: false)',
        match => 'update_lock.*json.*local',
      ;

      # Gem::Platform.match is deprecated; hide numerous warnings
      'pdk-fix-deprecation-warning':
        path  => "${pdk_gem_dir}/lib/pdk/util/puppet_version.rb",
        line  => "spec_tuple.name == 'puppet' && Gem::Platform.match_spec?(spec_tuple)",
        match => 'spec_tuple.*Gem::Platform\.match',
      ;
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
