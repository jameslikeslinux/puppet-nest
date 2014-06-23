class puppet::agent (
    $master        = 'puppet',
    $certname      = undef,
    $dns_alt_names = undef,
) {
    portage::package { [
        'app-admin/puppet',
        'dev-ruby/ruby-shadow',
    ]:
        ensure => installed,
    }

    file { '/etc/puppet/puppet.conf':
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
            File['/etc/puppet/puppet.conf'],
            Class['cronie'],
        ],
    }
}
