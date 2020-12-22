class nest::base::puppet {
  $dns_alt_names = $::nest::openvpn_server ? {
    true    => [$::nest::openvpn_hostname],
    default => [],
  }

  if $facts['osfamily'] == 'Gentoo' {
    file { [
      '/etc/puppetlabs',
      '/etc/puppetlabs/facter',
      '/etc/puppetlabs/facter/facts.d',
    ]:
      ensure => 'directory',
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
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

    $outputs_facts = @("OUTPUTS_FACTS")
      ---
      primary_output: '${::nest::primary_monitor}'
      scaling:
        gui: ${::nest::gui_scaling_factor}
        text: ${::nest::text_scaling_factor}
      | OUTPUTS_FACTS

    file { '/etc/puppetlabs/facter/facts.d/outputs.yaml':
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => $outputs_facts,
    }

    file { '/etc/puppetlabs/facter/facts.d/scaling.yaml':
      ensure => absent,
    };

    # My hosts take on the domain name of the network to which they're attached.
    # Provide a stable, canonical value for Puppet.
    file { '/etc/puppetlabs/facter/facts.d/fqdn.yaml':
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => "fqdn: ${trusted['certname']}.nest\n",
    }

    if $facts['build'] == 'stage1' or $facts['tool'] {
      $puppet_runmode = 'unmanaged'
    } else {
      $puppet_runmode = 'systemd.timer'
    }

    class { 'puppet':
      dns_alt_names        => $dns_alt_names,
      dir                  => '/etc/puppetlabs/puppet',
      codedir              => '/etc/puppetlabs/code',
      ssldir               => '/etc/puppetlabs/puppet/ssl',
      runmode              => $puppet_runmode,
      unavailable_runmodes => ['cron'],
    }
  } else {
    class { 'puppet':
      dns_alt_names => $dns_alt_names,
    }
  }
}
