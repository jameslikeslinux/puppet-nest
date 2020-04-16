class nest::base::puppet {
  $dns_alt_names = $::nest::openvpn_server ? {
    true    => [$::nest::openvpn_hostname],
    default => [],
  }

  class { '::puppet':
    dns_alt_names => $dns_alt_names,
  }

  if $facts['osfamily'] == 'Gentoo' {
    if $::nest::puppet_server {
      nest::lib::srv { 'puppetserver': }

      file { '/srv/puppetserver/hiera.yaml':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/nest/puppet/hiera.yaml',
        require => Nest::Lib::Srv['puppetserver'],
      }

      package { 'r10k':
        ensure => installed,
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

      file { '/etc/eyaml':
        ensure => directory,
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
      }

      $eyaml_config = @(EOT)
        ---
        pkcs7_private_key: '/srv/puppetserver/ssl/ca/ca_key.pem'
        pkcs7_public_key: '/srv/puppetserver/ssl/certs/ca.pem'
        | EOT

      file { '/etc/eyaml/config.yaml':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => $eyaml_config,
      }
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
  }
}
