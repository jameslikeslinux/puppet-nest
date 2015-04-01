class nest::role::thestaticvoid {
    unless lamp_server in $nest::roles {
        fail("Must have 'lamp_server' role to be 'thestaticvoid'")
    }

    apache::vhost { 'thestaticvoid':
        source => 'puppet:///modules/nest/role/thestaticvoid/vhost.conf',
    }

    include php::ssh2
}
