node 'hawk' {
    class { 'nest':
        cpu_governor   => 'performance',
        hugepages      => 8192,
        numa           => true,
        remote_backup  => true,
        boot_disk      => ['EFI1', 'EFI2'],
        boot_options   => ['intel_iommu=on', 'pci-stub.ids=10de:0fbc,1b21:1142'],
        resolution     => native,
        serial_console => '1',
        keymap         => 'us',
        mouse          => 'mxmaster',
        video_cards    => ['nvidia'],
        video_options  => {'metamodes' => 'DP-3: nvidia-auto-select +2560+0, DP-2: nvidia-auto-select +0+0', 'nvidiaXineramaInfoOrder' => 'DFP-4'},
        roles          => [
            compile_server,
            desktop,
            heloandnala,
            kvm_hypervisor,
            #lamp_server,
            nest_server,
            package_server,
            private_stuff,
            #puppet_dashboard,
            puppet_master,
            qemu_chroot,
            server,
            #subsonic_server,
            synergy_server,
            terminal_client,
            vpn_server,
            web_server,
            work_system,
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

    crypt::device { '/dev/disk/by-id/ata-ST2000DL003-9VT166_5YD15L2S':
        target => 'nest-crypt4',
        uuid   => '65026965-175b-4ad5-ad72-d43d9aa9f49e',
    }

    crypt::device { '/dev/disk/by-id/ata-ST2000DL003-9VT166_5YD23E8Q':
        target => 'nest-crypt5',
        uuid   => '92e07c04-1a1f-491e-acfe-e1fc5e7b70fd',
    }

    crypt::device { '/dev/disk/by-id/ata-ST2000DM001-1CH164_Z1E59EN3':
        target => 'nest-crypt6',
        uuid   => '557c6352-8d5e-4533-90b7-d60cf49c65ff',
    }

    crypt::device { '/dev/disk/by-id/ata-ST2000DM001-1CH164_Z341098C':
        target => 'nest-crypt7',
        uuid   => '3ab8cbc0-68e5-43e1-b50f-871b0f6cfda3',
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
        'motox',
    ]: }


    #
    # Settings to assist PCI passthrough
    #
    dracut::conf { 'pci-stub':
        force_drivers => ['pci-stub'],
    }

    file_line { 'nvidia_assign_gpus':
        path    => '/etc/modprobe.d/nvidia.conf',
        line    => 'options nvidia NVreg_DeviceFileMode=432 NVreg_DeviceFileUID=0 NVreg_DeviceFileGID=27 NVreg_ModifyDeviceFiles=1 NVreg_AssignGpus="0:03:00.0"',
        match   => '^options nvidia',
        require => Class['xorg'],
        notify  => Class['kernel::initrd'],
    }
}

@openvpn::host { 'hawk':
    ip => '172.22.2.1',
}

@sshkey { 'hawk':
    type => 'ssh-ed25519',
    key  => 'AAAAC3NzaC1lZDI1NTE5AAAAILOupauddUKhsCWzXiYpr/7uRe4aWsHgrIf8G7s339vc',
}

@cups::browse { 'hawk': }

@openvpn::host { 'm8':
    ip => '172.22.2.10',
}

@openvpn::host { 'motox':
    ip => '172.22.2.14',
}
