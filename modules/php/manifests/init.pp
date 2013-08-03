class php (
    $timezone = 'UTC',
    $apache   = false,
    $mysql    = false,
) {
    if $apache and $mysql {
        $use = ['cgi', 'mysql']
    } elsif $apache {
        $use = 'cgi'
    } elsif $mysql { 
        $use = 'mysql'
    } else {
        $use = undef
    }

    portage::package { 'dev-lang/php':
        use => $use,
    }

    php::config { 'cli-php5.5': }

    if $apache {
        php::config { 'cgi-php5.5':
            # XXX: Is there a better way to tell apache to restart?
            notify => Openrc::Service['apache2'],
        }

        apache::module { 'php':
            source  => 'puppet:///modules/php/php.conf',
            require => [
                Portage::Package['dev-lang/php'],
                Php::Config['cgi-php5.5'],
            ],
        }
    }
}
