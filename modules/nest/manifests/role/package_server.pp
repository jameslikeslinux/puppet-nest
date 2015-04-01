class nest::role::package_server {
    unless web_server in $nest::roles {
        fail("Must have 'web_server' role to be 'package_server'")
    }

    class { 'package::server':
        short_name  => 'packages',
        domain_name => 'thestaticvoid.com', # or $domain
    }
}
