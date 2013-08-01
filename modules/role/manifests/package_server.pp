class role::package_server {
    include role::web_server

    class { 'package::server': }
}
