if $trusted['certname'] in ['bolt', 'puppetdb'] {
  fail("${trusted['certname']} is not allowed to use Puppet")
}

case $facts['os']['family'] {
  'Gentoo': {
    Firewalld_zone {
      interfaces       => [],
      sources          => [],
      masquerade       => false,
      purge_rich_rules => true,
      purge_services   => true,
      purge_ports      => true,
    }

    # MariaDB defaults
    Mysql::Db {
      charset => 'utf8mb3',
      collate => 'utf8mb3_general_ci',
    }

    Service {
      provider => 'systemd',
    }

    Sysctl {
      target  => '/etc/sysctl.d/nest.conf',
      require => File['/etc/sysctl.d'],
    }

    # Effectively disable resources that can't be managed in containers
    if $facts['is_container'] {
      Service <||> {
        ensure => undef,
      }

      Sysctl <||> {
        apply => false,
      }
    }
  }

  'windows': {
    Concat {
      # The default is usually 0644, but Windows keeps changing it to 0674, so
      # just accept what it does.
      mode => '0674',
    }
  }
}

hiera_include('classes')
