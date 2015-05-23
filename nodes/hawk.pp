node 'hawk' {
    class { 'nest':
        remote_backup    => true,
        boot_disk        => ['EFI1', 'EFI2'],
        boot_options     => ['intel_iommu=on', 'pci-stub.ids=10de:0fbc,1b21:1142', 'console=ttyS1,115200n8', 'console=tty0'],
        resolution       => native,
        keymap           => 'us',
        video_cards      => ['nvidia'],
        video_options    => {'metamodes' => 'DP-3: nvidia-auto-select +2560+0, DP-2: nvidia-auto-select +0+0', 'nvidiaXineramaInfoOrder' => 'DFP-4'},
        roles            => [
            compile_server,
            desktop,
            kvm_hypervisor,
            #lamp_server,
            nest_server,
            package_server,
            private_stuff,
            #puppet_dashboard,
            puppet_master,
            qemu_chroot,
            server,
            subsonic_server,
            synergy_server,
            terminal_client,
            vpn_server,
            web_server,
            #work_system,
        ],
    }
    
    crypt::device { '/dev/disk/by-id/ata-Samsung_SSD_840_PRO_Series_S1ATNSAD907240P-part3':
        target => 'rpool-crypt0',
        uuid   => '1128986e-ae39-4ebe-bda4-8f08ae8603ef',
    }

    crypt::device { '/dev/disk/by-id/ata-Samsung_SSD_840_PRO_Series_S1ATNSAD908564X-part3':
        target => 'rpool-crypt1',
        uuid   => '8bd2bf2b-1037-406d-936f-c86b36783e1f',
    }

    crypt::device { '/dev/disk/by-id/ata-WDC_WD40EFRX-68WT0N0_WD-WCC4E0TPK950':
        target => 'nest-crypt0',
        uuid   => 'f4dc141c-b9a4-4ca7-9b1f-333b80475113',
    }

    crypt::device { '/dev/disk/by-id/ata-WDC_WD40EFRX-68WT0N0_WD-WCC4E2KDDSP9':
        target => 'nest-crypt1',
        uuid   => 'b8bcf96c-c29e-4241-af43-4b6759fa532d',
    }

    crypt::device { '/dev/disk/by-id/ata-WDC_WD40EFRX-68WT0N0_WD-WCC4E2ND3N59':
        target => 'nest-crypt2',
        uuid   => 'eab4b536-fe5e-4ea4-91aa-85107dcb224c',
    }

    crypt::device { '/dev/disk/by-id/ata-WDC_WD40EFRX-68WT0N0_WD-WCC4E7XTNL8V':
        target => 'nest-crypt3',
        uuid   => '25a93cd2-ad0d-4bc4-a437-8e2f5211f87a',
    }

    package_mask { 'x11-drivers/nvidia-drivers':
        version => '>=341.0.0',
        ensure  => absent,
    }

    class { 'inkscape': }

    #
    # Allow SSH for access to VPN.  This is OK...
    # password authentication is DISABLED.
    #
    iptables::accept { 'ssh':
        port     => 22,
        protocol => tcp,
    }

    #
    # Allow multicast for Chromecast support
    #
    class { 'iptables::multicast': }

    #
    # Create VPN profiles for phone and tablet
    #
    openvpn::mobile { [
        'm8',
        'nexus7',
    ]: }


    #
    # Settings to assist PCI passthrough
    #
    dracut::conf { 'pci-stub':
        force_drivers => ['pci-stub'],
    }

    file_line { 'nvidia_assign_gpus':
        path    => '/etc/modprobe.d/nvidia.conf',
        line    => 'options nvidia NVreg_DeviceFileMode=432 NVreg_DeviceFileUID=0 NVreg_DeviceFileGID=27 NVreg_ModifyDeviceFiles=1 NVreg_AssignGpus="0:04:00.0"',
        match   => '^options nvidia',
        require => Class['xorg'],
        notify  => Class['kernel::initrd'],
    }
}

@openvpn::host { 'hawk':
    ip => '172.22.2.1',
}

@sshkey { 'hawk':
    type => 'ssh-dss',
    key  => 'AAAAB3NzaC1kc3MAAACBAIEmwKhaBY1AIKUqqbGEEeHzALhx0qnuuqqPVkE3OabL8wv5fSczGsCltou2fOxP5skaKG15qDw4e7Q96qt4JA2J4STmMTTosuLuE+XwlGD9pNkv+KNMcpPOzLDZ24jx77smjuswg6Ij7vYPwDUQL4EQqtdYXpXK0Cg5qnWCkeIFAAAAFQDhZCDDU12OVam85hDNTSl6GXMeXQAAAIBTAlOo337b3zO8qlVaVrunx65LLlM2iK9viWNKLB46lsK61BlOVGLIj37rM16XsGWzl3SNxG7QKhXwi06Gx2kFEABPx42xTRYeqLyqAYHehFTStEVUeVFJD43kcH32VEyzI7y0w158jf/80yYheI5UVCt3Lasu60AOXChRmq5pmAAAAIBUlAMeCTFBJ+Qcszm/UwIXOv+ezBra5X5XbAwJhsFeCioTUo9X2GaHbYgZOk3cDgk+wXeuRwv4hn9tYTyhUokCIn4wIPQihMGVXtagFcEp49gPg12DjcdAdDejPsvwh7q0zKMQLqdrn9ULbURbulxPOUCDZ1Jom42bDzVebVyG9Q==',
}

@cups::browse { 'hawk': }

@openvpn::host { 'm8':
    ip => '172.22.2.10',
}
