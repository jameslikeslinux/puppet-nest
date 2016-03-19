class puppet::agent (
    $master        = 'puppet',
    $certname      = undef,
    $dns_alt_names = undef,
) {
    if $architecture =~ /arm/ {
        package_keywords { [
            'dev-ruby/facter',
            'dev-ruby/hiera',
            'app-emulation/virt-what',
            'app-admin/puppet',
            'dev-ruby/rgen',
            'dev-ruby/ruby-shadow',
            'app-doc/NaturalDocs',
            'app-admin/augeas',
            'dev-ruby/ruby-augeas',
            'dev-ruby/deep_merge',
        ]:
            keywords => '**',
            target   => 'puppet',
            version  => '<9999',
            ensure   => 'present',
            before   => Portage::Package['app-admin/puppet'],
        }
    }

    portage::package { 'app-admin/puppet':
        ensure => installed,
        use    => 'augeas',
    }

    portage::package { 'dev-ruby/ruby-shadow':
        ensure => installed,
    }

    file { '/etc/puppetlabs/puppet/puppet.conf':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('puppet/agent.erb'),
        require => Portage::Package['app-admin/puppet'],
    }

    openrc::service { 'puppet':
        enable => false,
    }

    file { '/etc/cron.daily/puppet':
        mode    => '0755',
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/puppet/cron.sh',
        require => [
            File['/etc/puppetlabs/puppet/puppet.conf'],
            Class['cronie'],
        ],
    }
}
