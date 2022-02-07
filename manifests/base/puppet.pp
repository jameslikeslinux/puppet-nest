class nest::base::puppet {
  $dns_alt_names = $::nest::openvpn_server ? {
    true    => [$::nest::openvpn_hostname],
    default => [],
  }

  case $facts['os']['family'] {
    'Gentoo': {
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
        content => "---\nfqdn: '${trusted['certname']}.nest'\n",
      }

      if $facts['build'] or $facts['running_live'] {
        $puppet_runmode = 'unmanaged'
      } else {
        $puppet_runmode = 'systemd.timer'
      }

      file {
        default:
          mode  => '0644',
          owner => 'root',
          group => 'root',
        ;

        '/etc/systemd/system/puppet-run.timer.d':
          ensure => directory,
        ;

        # Avoid running Puppet immediately at boot; just wait for the next run
        '/etc/systemd/system/puppet-run.timer.d/10-nonpersistent.conf':
          content => "[Timer]\nPersistent=false\n",
        ;
      }
      ->
      class { 'puppet':
        dns_alt_names        => $dns_alt_names,
        dir                  => '/etc/puppetlabs/puppet',
        codedir              => '/etc/puppetlabs/code',
        ssldir               => '/etc/puppetlabs/puppet/ssl',
        runmode              => $puppet_runmode,
        unavailable_runmodes => ['cron'],
        additional_settings  => {
          'publicdir' => '/var/lib/puppet/public',
        },
      }

      # For compatibility with Bolt 'puppet-agent' feature
      file {
        default:
          mode  => '0644',
          owner => 'root',
          group => 'root',
        ;

        [
          '/opt/puppetlabs',
          '/opt/puppetlabs/puppet',
          '/opt/puppetlabs/puppet/bin',
        ]:
          ensure => directory,
        ;

        '/opt/puppetlabs/puppet/bin/ruby':
          ensure => link,
          target => '/usr/bin/ruby',
        ;
      }
    }

    'windows': {
      $facter_conf = @(FACTER_CONF)
        global : {
            external-dir : [ "C:/ProgramData/PuppetLabs/facter/facts.d" ]
        }
        | FACTER_CONF

      file {
        default:
          mode    => '0644',
          owner   => 'Administrators',
          group   => 'None',
        ;

        'C:/ProgramData/PuppetLabs/facter/etc':
          ensure => directory,
        ;

        'C:/ProgramData/PuppetLabs/facter/etc/facter.conf':
          content => $facter_conf,
        ;
      }

      $outputs_facts = @("OUTPUTS_FACTS")
        ---
        scaling:
          gui: ${::nest::gui_scaling_factor}
          text: ${::nest::text_scaling_factor}
        | OUTPUTS_FACTS

      file { 'C:/ProgramData/PuppetLabs/facter/facts.d/outputs.yaml':
        mode    => '0644',
        owner   => 'Administrators',
        group   => 'None',
        content => $outputs_facts,
      }

      class { 'puppet':
        dns_alt_names => $dns_alt_names,
      }
    }
  }
}
