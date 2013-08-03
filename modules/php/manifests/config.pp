define php::config {
    file { "/etc/php/${name}/php.ini":
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('php/php.ini.erb'),
        require => Portage::Package['dev-lang/php'],
    }
}
