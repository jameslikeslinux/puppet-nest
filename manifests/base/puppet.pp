class nest::base::puppet {
  $dns_alt_names = $::nest::openvpn_server ? {
    true    => [$::nest::openvpn_hostname],
    default => [],
  }

  if $facts['osfamily'] == 'Gentoo' {
    file {
      default:
        mode  => '0644',
        owner => 'root',
        group => 'root',
      ;

      [
        '/etc/portage/patches/app-admin',
        '/etc/portage/patches/app-admin/puppet',
      ]:
        ensure => directory,
      ;

      '/etc/portage/patches/app-admin/puppet/puppet-service-provider-systemd-gentoo-default.patch':
        source => 'puppet:///modules/nest/puppet/puppet-service-provider-systemd-gentoo-default.patch',
      ;
    }

    $facter_conf = @(FACTER_CONF)
      global : {
          external-dir : [ "/etc/puppetlabs/facter/facts.d" ]
      }
      | FACTER_CONF

    file { '/etc/puppetlabs/facter/facter.conf':
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => $facter_conf,
    }

    $scaling_facts = @("SCALING_FACTS")
      ---
      scaling:
        gui: ${::nest::gui_scaling_factor}
        text: ${::nest::text_scaling_factor}
      | SCALING_FACTS

    file { '/etc/puppetlabs/facter/facts.d/scaling.yaml':
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => $scaling_facts,
    }

    class { '::puppet':
      dns_alt_names => $dns_alt_names,
      dir           => '/etc/puppetlabs/puppet',
      codedir       => '/etc/puppetlabs/code',
      ssldir        => '/etc/puppetlabs/puppet/ssl',
    }
  } else {
    class { '::puppet':
      dns_alt_names => $dns_alt_names,
    }
  }
}
