class nest::role::kvm_hypervisor {
    class { 'qemu':
        spice => true,
        numa  => $nest::numa,
    }

    class { 'libvirt':
        numa    => $nest::numa,
        require => Class['qemu'],
    }

    class { 'libvirt::manager':
        require => Class['libvirt'],
    }
}
