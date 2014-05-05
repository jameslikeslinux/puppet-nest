class php::ssh2 {
    portage::package { 'dev-php/pecl-ssh2':
        ensure => installed,
        notify => Openrc::Service['apache2'],
    }
}
