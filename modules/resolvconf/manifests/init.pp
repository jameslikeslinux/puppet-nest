class resolvconf (
    $search_domains = undef,
) {
    portage::package { 'net-dns/openresolv':
        ensure => 'installed',
    }

    file { '/etc/resolvconf.conf':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('resolvconf/resolvconf.conf.erb'),
        require => Portage::Package['net-dns/openresolv'],
        notify  => Exec['/sbin/resolvconf -u'],
    }

    exec { '/sbin/resolvconf -u':
        refreshonly => true,
    }
}
