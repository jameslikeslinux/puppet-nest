class nest::role::heloandnala {
    unless web_server in $nest::roles {
        fail("Must have 'web_server' role to be 'heloandnala'")
    }

    case $clientcert {
        'osprey': {
            $listen80 = '104.156.227.40:80 [2001:19f0:300:2005::40]:80'
            $listen443 = '104.156.227.40:443 [2001:19f0:300:2005::40]:443'
        }

        default: {
            $listen80 = '*:80'
            $listen443 = '*:443'
        }
    }

    apache::vhost { 'heloandnala':
        content => template('nest/role/heloandnala/vhost.conf.erb'),
    }
}
