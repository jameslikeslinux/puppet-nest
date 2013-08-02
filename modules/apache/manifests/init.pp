class apache (
    $define = undef,
) {
    $default_apache_modules = 'actions alias auth_basic authn_alias authn_anon authn_core authn_dbm authn_file authz_core authz_dbm authz_groupfile authz_host authz_owner authz_user autoindex cache cgi cgid dav dav_fs dav_lock deflate dir env expires ext_filter file_cache filter headers include info log_config logio mime mime_magic negotiation rewrite setenvif socache_shmcb speling status unique_id unixd userdir usertrack vhost_alias'

    portage::makeconf { 'apache2_modules':
        content => "${default_apache_modules} proxy proxy_ajp proxy_http",
    }

    portage::makeconf { 'apache2_mpms':
        content => 'worker',
    }

    portage::package { 'www-servers/apache':
        ensure => installed,
        use    => 'threads',
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
