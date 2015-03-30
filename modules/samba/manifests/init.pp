class samba {
    portage::package { 'net-fs/samba':
        ensure       => installed,
        mask_version => '>=4.0.0',
    }
}
