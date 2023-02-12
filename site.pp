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
    Firewalld_service {
      zone => 'external',
    }

    Firewalld_port {
      zone => 'external',
    }

    Firewalld_rich_rule {
      zone => 'external',
    }

    Firewalld_zone {
      interfaces       => [],
      sources          => [],
      masquerade       => false,
      purge_rich_rules => true,
      purge_services   => true,
      purge_ports      => true,
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
