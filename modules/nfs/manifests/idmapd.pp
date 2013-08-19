class nfs::idmapd (
    $domain,
) {
    file { '/etc/idmapd.conf':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('nfs/idmapd.conf.erb'),
        require => Class['nfs'],
        notify  => Openrc::Service['rpc.idmapd'],
    }

    openrc::service { 'rpc.idmapd':
        enable  => true,
        require => File['/etc/idmapd.conf'],
    }
}
