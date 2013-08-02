class profile::role::puppet_master {
    class { 'puppet::master':
        modulepath => ['$manifestdir/modules', '$manifestdir/forge'],
    }
}
