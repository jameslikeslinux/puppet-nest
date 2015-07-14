class puppet::master inherits puppet::agent {
    File['/etc/puppetlabs/puppet/puppet.conf'] {
        content => template('puppet/agent.erb', 'puppet/master.erb'),
        notify  +> Openrc::Service['puppetmaster'],
    }

    openrc::service { 'puppetmaster':
        enable => true,
    }
}
