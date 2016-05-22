class nest::profile::base::puppet {
  if $::nest::server == true {
    class { '::puppet':
      dns_alt_names               => ['puppet', "${::trusted['certname']}.nest", 'nest.james.tl'],
      puppetmaster                => "${::trusted['certname']}.nest",
      server                      => true,
      server_dynamic_environments => true,
      server_environments         => [],
      server_external_nodes       => '',
      server_foreman              => false,
      server_implementation       => 'puppetserver',
      server_jvm_config           => '/etc/conf.d/puppetserver',
      unavailable_runmodes        => ['cron'],
    }

    # Package installs the log directory with incorrect permissions
    file { '/var/log/puppetlabs/puppetserver':
      ensure  => directory,
      mode    => '0750',
      owner   => 'puppet',
      group   => 'puppet',
      require => Class['::puppet::server::install'],
      before  => Class['::puppet::server::service'],
    }

    package { 'hiera-eyaml':
      ensure   => installed,
      provider => puppetserver_gem,
    }

    file { '/etc/puppetlabs/code/hiera.yaml':
      mode => '0644',
      owner => 'root',
      group => 'root',
      source => 'puppet:///modules/nest/puppet/hiera.yaml'
    }

    Class['::puppet::server::install'] ->
    Package['hiera-eyaml'] ->
    File['/etc/puppetlabs/code/hiera.yaml'] ~>
    Class['::puppet::server::service']

    package { 'r10k':
      ensure   => installed,
      provider => puppet_gem,
    }

    file { '/etc/puppetlabs/r10k':
      ensure => directory,
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
    }

    file { '/etc/puppetlabs/r10k/r10k.yaml':
      mode   => '0644',
      owner  => 'root',
      group  => 'root',
      source => 'puppet:///modules/nest/puppet/r10k.yaml',
    }
  } else {
    class { '::puppet':
      puppetmaster         => $::nest::server,
      unavailable_runmodes => ['cron'],
    }
  }

  package { 'dev-ruby/hiera-eyaml':
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
