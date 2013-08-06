class profile::role::laptop {
    portage::package { 'sys-kernel/linux-firmware':
        ensure => installed,
    }
}
