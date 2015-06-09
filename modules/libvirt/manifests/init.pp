class libvirt (
    $numa = false,
) {
    $use = [
        'virt-network',

        $numa ? {
            false   => [],
            default => 'numa',
        },
    ]

    package_use { 'net-dns/dnsmasq':
        use => 'script',
    }

    portage::package { 'net-analyzer/netcat':
        ensure => absent,
    }

    portage::package { 'app-emulation/libvirt':
        ensure  => installed,
        use     => flatten($use),
        require => [
            Package_use['net-dns/dnsmasq'],
            Portage::Package['net-analyzer/netcat'],
        ],
    }

    file_line { 'libvirt-enable-host-audio':
        path    => '/etc/libvirt/qemu.conf',
        match   => '^#vnc_allow_host_audio =.*',
        line    => 'vnc_allow_host_audio = 1',
        require => Portage::Package['app-emulation/libvirt'],
    }

    file_line { 'libvirtd-shutdown-guests':
        path    => '/etc/conf.d/libvirtd',
        match   => '^LIBVIRTD_KVM_SHUTDOWN="managedsave"',
        line    => 'LIBVIRTD_KVM_SHUTDOWN="shutdown"',
        require => Portage::Package['app-emulation/libvirt'],
    }

    user { 'qemu':
        groups  => ['audio', 'kvm'],
        require => Portage::Package['app-emulation/libvirt'],
    }

    openrc::service { 'libvirtd':
        enable  => true,
        require => File_line['libvirtd-shutdown-guests'],
    }
}
