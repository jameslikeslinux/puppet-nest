class profile::role::thestaticvoid {
    unless lamp_server in $profile::base::roles {
        fail("Must have 'lamp_server' role to be 'thestaticvoid'")
    }

    apache::vhost { 'thestaticvoid':
        source => 'puppet:///modules/profile/role/thestaticvoid/vhost.conf',
    }
}
