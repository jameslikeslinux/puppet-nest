class distcc {
    portage::package { 'sys-devel/distcc':
        ensure => installed,
    }    
}
