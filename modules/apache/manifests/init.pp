class apache (
    $modules = [],
) {
    portage::package { 'www-servers/apache':
        ensure => installed,
        use    => [
            'threads',
            'apache2_modules_proxy',
            'apache2_modules_proxy_ajp',
            'apache2_modules_proxy_http',
            'apache2_mpms_worker',
        ],
    }

    if fcgid in $modules {
        portage::package { 'www-apache/mod_fcgid':
            require => Portage::Package['www-servers/apache'],
        }
    }

    #
    # Add ability to set defines
    #
    file { '/etc/conf.d/apache2':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('apache/confd.erb'),
        require => Portage::Package['www-servers/apache'],
        notify  => Openrc::Service['apache2'],
    }

    #
    # Disable indexes by default
    #
    file { '/var/www/localhost/htdocs/.htaccess':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => 'Options -Indexes',
        require => Portage::Package['www-servers/apache'],
    }

    openrc::service { 'apache2':
        enable  => true,
        require => Portage::Package['www-servers/apache'],
    }
}
