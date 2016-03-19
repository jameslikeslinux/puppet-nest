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

    # required by app-emulation/qemu-2.4.0[-qemu_softmmu_targets_cris,-qemu_softmmu_targets_sh4,-qemu_softmmu_targets_ppc,-qemu_softmmu_targets_sparc,-qemu_softmmu_targets_sparc64,-qemu_softmmu_targets_microblaze,-qemu_softmmu_targets_alpha,-qemu_softmmu_targets_xtensaeb,-qemu_softmmu_targets_arm,-qemu_softmmu_targets_mips,-qemu_softmmu_targets_s390x,-qemu_softmmu_targets_mips64,-qemu_softmmu_targets_aarch64,-qemu_softmmu_targets_moxie,qemu_softmmu_targets_i386,-qemu_softmmu_targets_ppcemb,-qemu_softmmu_targets_sh4eb,-qemu_softmmu_targets_ppc64,-qemu_softmmu_targets_microblazeel,-qemu_softmmu_targets_unicore32,-qemu_softmmu_targets_xtensa,opengl,-qemu_softmmu_targets_mipsel,-qemu_softmmu_targets_lm32,qemu_softmmu_targets_x86_64,-static-softmmu,-qemu_softmmu_targets_m68k,-qemu_softmmu_targets_or32,-qemu_softmmu_targets_mips64el]
    # required by app-emulation/libvirt-1.2.18-r1[qemu]
    # required by app-emulation/libvirt-glib-0.2.0
    # required by @__auto_slot_operator_replace_installed__ (argument)
    package_use { 'media-libs/mesa':
        use    => 'gles2',
        before => Portage::Package['app-emulation/libvirt'],
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

    file_line { 'libvirt-guests-shutdown-guests':
        path    => '/etc/conf.d/libvirt-guests',
        match   => '^.?LIBVIRT_SHUTDOWN="managedsave"',
        line    => 'LIBVIRT_SHUTDOWN="shutdown"',
        require => Portage::Package['app-emulation/libvirt'],
    }

    user { 'qemu':
        groups  => ['audio', 'kvm'],
        require => Portage::Package['app-emulation/libvirt'],
    }

    openrc::service { [
        'libvirtd',
        'virtlogd',
    ]:
        enable  => true,
        require => Portage::Package['app-emulation/libvirt'],
    }

    openrc::service { 'libvirt-guests':
        enable  => true,
        require => File_line['libvirt-guests-shutdown-guests'],
    }

    kernel::modules { 'libvirt':
        content => "modules=\"vfio-pci\"\n",
    }
}
