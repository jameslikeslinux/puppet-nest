class openconnect {
    # Fix stupid Portage
    include misc::boehmgc

    portage::package { 'net-misc/openconnect':
        require => Class['misc::boehmgc'],
    }
}
