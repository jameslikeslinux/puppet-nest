class profile::role::puppet_master {
    class { 'puppet::master':
        environmentpath => '$confdir/environments',
    }

    iptables::accept { 'puppet':
        port     => 8140,
        protocol => tcp,
    }
}
