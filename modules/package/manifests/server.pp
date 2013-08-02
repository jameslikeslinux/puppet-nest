class package::server (
    $short_name,
    $domain_name,
    $package_dir = '/usr/portage/packages',
) {
    $fqdn = "${short_name}.${domain_name}"

    file { '/var/www/localhost/htdocs/packages':
        ensure  => link,
        target  => $package_dir,
        require => Class['apache'],
    }

    apache::vhost { $short_name:
        content => template('package/vhost.conf.erb'),
    }
}
