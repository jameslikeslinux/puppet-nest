class nest::role::puppet_master {
    class { 'puppet::master': }

    iptables::accept { 'puppet':
        port     => 8140,
        protocol => tcp,
    }
}
