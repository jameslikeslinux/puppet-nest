class profile::role::kvm_hypervisor {
    class { 'qemu':
        spice => true,
    }

    class { [
        'libvirt',
        'libvirt::manager',
    ]:
        require => Class['qemu'],
    }
}
