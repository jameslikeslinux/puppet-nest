class nest::node::gateway {
  nest::lib::package { 'app-crypt/certbot':
    ensure => installed,
  }
}
