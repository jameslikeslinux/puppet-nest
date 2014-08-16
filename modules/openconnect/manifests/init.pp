class openconnect {
    # Fix stupid Portage
    include misc::boehmgc

    portage::package { 'net-misc/openconnect':
        mask_version => '~5.99',
        require      => Class['misc::boehmgc'],
    }
}
