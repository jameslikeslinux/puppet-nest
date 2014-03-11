class profile::role::ssh_server {
    class { 'ssh': }

    class { 'ssh::server':
        challengeresponse => true,
    }

#    iptables::accept { 'ssh':
#        port     => 22,
#        protocol => tcp,
#    }
}
