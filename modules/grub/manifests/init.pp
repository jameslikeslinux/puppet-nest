class grub {
    portage::package { 'sys-boot/grub':
        ensure => installed,
    }
}
