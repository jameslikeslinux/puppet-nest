class openconnect {
    # Fix stupid Portage
    include misc::boehmgc

    portage::package { 'net-misc/openconnect':
        mask_version => '>=7.01',
        require      => Class['misc::boehmgc'],
    }
}
