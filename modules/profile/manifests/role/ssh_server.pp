class profile::role::ssh_server {
    class { ['ssh', 'ssh::server']: }

#    iptables::accept { 'ssh':
#        port     => 22,
#        protocol => tcp,
#    }
}
