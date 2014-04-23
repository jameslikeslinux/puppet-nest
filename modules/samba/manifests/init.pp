class samba {
    portage::package { 'net-fs/samba':
        ensure => installed,
    }
}
