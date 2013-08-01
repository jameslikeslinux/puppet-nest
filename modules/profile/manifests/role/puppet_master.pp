class profile::role::puppet_master {
    class { 'puppet::master':
        dns_alt_names => ['puppet.thestaticvoid.com', 'vpn.thestaticvoid.com'],
        modulepath    => ['$manifestdir/modules', '$manifestdir/forge'],
    }
}
