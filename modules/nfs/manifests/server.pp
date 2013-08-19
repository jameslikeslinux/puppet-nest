class nfs::server {
    openrc::service { 'nfs':
        enable  => true,
        require => Class['nfs'],
    }
}
