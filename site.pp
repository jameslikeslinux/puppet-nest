if $trusted['certname'] in ['bolt', 'puppetdb'] {
  fail("${trusted['certname']} is not allowed to use Puppet")
}

class choco {
  include chocolatey

  chocolateyfeature { 'useRememberedArgumentsForUpgrades':
    ensure => enabled,
  }
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

    stage { 'first':
      before => Stage['main'],
    }

    class { 'choco':
      stage => 'first',
    }

    Package {
      provider => 'chocolatey',
    }
  }
}

hiera_include('classes')
