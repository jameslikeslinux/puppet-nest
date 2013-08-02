class puppet::master (
    $modulepath    = undef,
) inherits puppet::agent {
    File['/etc/puppet/puppet.conf'] {
        content => template('puppet/agent.erb', 'puppet/master.erb'),
        notify  +> Openrc::Service['puppetmaster'],
    }

    openrc::service { 'puppetmaster':
        enable => true,
    }
}
