class openconnect {
    portage::package { 'net-misc/openconnect':
        mask_version => '=5.99',
    }
}
