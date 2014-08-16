class qemu {
    portage::package { 'app-emulation/qemu':
        ensure  => installed,
    }
}
