class libvirt::manager {
    include libvirt

    package_use { 'net-misc/spice-gtk':
        use => ['gtk3', 'usbredir'],
    }

    portage::package { 'app-emulation/virt-manager':
        ensure  => installed,
        use     => 'gtk',
        require => Package_use['net-misc/spice-gtk'],
    }
}
