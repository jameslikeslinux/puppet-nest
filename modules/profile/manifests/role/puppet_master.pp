class profile::role::puppet_master {
    class { 'puppet::master':
        modulepath => ['$manifestdir/modules', '$manifestdir/forge'],
    }

    iptables::accept { 'puppet':
        port     => 8140,
        protocol => tcp,
    }
}
