class nest::base::puppet {
  tag 'build_prep'

  $dns_alt_names = $nest::openvpn ? {
    true    => $nest::openvpn_servers.filter |$s| { $s !~ Stdlib::IP::Address },
    default => [],
  }

  # lint:ignore:legacy_facts
  if $facts['build'] == 'stage3' and $facts['domain'] {
    $domain = $facts['domain']
  } elsif $facts['networking']['network'] == '172.22.4.0' and !$facts['networking']['interfaces']['tun0'] {
    $domain = 'eyrie'
  } else {
    $domain = 'nest'
  }
  # lint:endignore

  $fqdn = "${trusted['certname']}.${domain}"

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

      file { '/etc/puppetlabs/facter/facts.d/outputs.yaml':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => epp('nest/puppet/outputs.yaml.epp'),
      }

      # My hosts take on the domain name of the network to which they're attached.
      # Provide a stable, canonical value for Puppet.
      file { '/etc/puppetlabs/facter/facts.d/nest.yaml':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => "---\ndomain: '${domain}'\nfqdn: '${fqdn}'\n",
      }

      if $facts['build'] or $facts['running_live'] {
        $puppet_runmode = 'unmanaged'
      } elsif !$nest::puppet {
        $puppet_runmode = 'none'
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

      # Override failing systemd reload in build containers
      if $facts['is_container'] {
        Exec <| title == 'systemctl-daemon-reload-puppet' |> {
          noop => true,
        }
      }

      # XXX: Cleanup old fqdn external fact
      file { '/etc/puppetlabs/facter/facts.d/fqdn.yaml':
        ensure => absent,
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
          mode  => '0644',
          owner => 'Administrators',
          group => 'None',
        ;

        'C:/ProgramData/PuppetLabs/facter/etc':
          ensure => directory,
        ;

        'C:/ProgramData/PuppetLabs/facter/etc/facter.conf':
          content => $facter_conf,
        ;

        'C:/ProgramData/PuppetLabs/facter/facts.d/fqdn.yaml':
          content => "---\nfqdn: '${fqdn}'\n",
        ;
      }

      file { 'C:/ProgramData/PuppetLabs/facter/facts.d/outputs.yaml':
        mode    => '0644',
        owner   => 'Administrators',
        group   => 'None',
        content => epp('nest/puppet/outputs.yaml.epp'),
      }

      if $nest::puppet {
        $puppet_runmode = 'service'
      } else {
        $puppet_runmode = 'none'
      }

      class { 'puppet':
        dns_alt_names => $dns_alt_names,
        runmode       => $puppet_runmode,
      }
    }
  }
}
