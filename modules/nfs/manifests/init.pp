class nfs {
    portage::package { 'net-fs/nfs-utils':
        ensure => installed,
    }
}
