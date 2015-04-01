class nest::role::ssh_server {
    class { 'ssh': }

    class { 'ssh::server':
        challengeresponse => false,
    }

#    iptables::accept { 'ssh':
#        port     => 22,
#        protocol => tcp,
#    }
}
