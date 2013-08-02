class profile::role::package_server {
    include role::web_server

    class { 'package::server':
        short_name  => 'pkg',
        domain_name => 'thestaticvoid.com', # or $domain
    }
}
