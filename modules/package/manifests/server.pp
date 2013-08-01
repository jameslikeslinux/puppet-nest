class package::server {
    file { '/var/www/localhost/htdocs/packages':
        ensure  => link,
        target  => '/usr/portage/packages',
        require => Class['apache'],
    }
}
